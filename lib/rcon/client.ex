defmodule RCON.Client do
	@moduledoc """
	Provides functionality to connect to a RCON server.
	"""
	
	alias RCON.Packet
	
	@type connection :: {Socket.TCP.t, Packet.id}
	@type options :: [
		timeout: timeout
	]

	@auth_failed_id Packet.auth_failed_id

	@unexpected_packet_error "Unexpected packet"
	@unexpected_end_of_stream_error "Unexpected end of stream"

	@doc """
	Connects to an RCON server.
	"""
	@spec connect(Socket.Address.t, :inet.port_number, options) :: {:ok, connection} | {:error, Socket.Error.t}
	def connect(address, port, options \\ []) do
		timeout = Keyword.get(options, :timeout, :infinity)
		with {:ok, socket} <- Socket.TCP.connect(address, port, [timeout: timeout, as: :binary]) do
			{:ok, {socket, Packet.initial_id}}
		end
	end

	@doc """
	Authenticate a connection given a password.

	## Examples

	    # Successful auth
	    {:ok, conn, true} = RCON.Client.authenticate(conn, "correct-password")
	    # Failed auth
	    {:ok, conn, false} = RCON.Client.authenticate(conn, "bad-password")

	"""
	@spec authenticate(connection, binary) :: {:ok, connection, boolean} | {:error, binary}
	def authenticate(conn, password) do
		with {:ok, conn, packet_id} <- send(conn, :auth, password) do
			authenticate_recv(conn, packet_id)
		end
	end

	@spec authenticate_recv(connection, Packet.id) :: {:ok, connection, boolean} | {:error, binary}
	defp authenticate_recv(conn, packet_id) do
		case recv(conn) do
			# Drop any exec_resp packets (was a problem with CSGO?)
			# TODO: Check that this is still needed.
			{:ok, {:exec_resp, ^packet_id, _, _}} ->
				authenticate_recv(conn, packet_id)
			# Handle successful auth
			{:ok, {:auth_resp, ^packet_id, _, _}} ->
				{:ok, conn, true}
			# Handle failed auth
			{:ok, {:auth_resp, @auth_failed_id, _, _}} ->
				{:ok, conn, false}
			{:ok, {bad_kind, bad_id, _, _}} ->
				{:error, unexpected_packet_error(bad_kind, bad_id)}
			{:error, err} ->
				{:error, err}
		end
	end

	@doc """
	Execute a command.

	## Examples

	    {:ok, conn, "command response..."} = RCON.Client.exec(conn, "command...")

	"""
	@spec exec(connection, binary) :: {:ok, connection, binary} | {:error, binary}
	def exec(conn, command) do
		# We first send the command, followed by sending an empty exec_resp.
		# The RCON server should respond in order of the messages received,
		# and also mirror back the empty exec_resp.
		# This allows us to easily handle multi-packet responses.
		# https://developer.valvesoftware.com/wiki/Source_RCON_Protocol#Multiple-packet_Responses
		with {:ok, conn, cmd_id} <- send(conn, :exec, command), # Send the command
		     {:ok, conn, end_id} <- send(conn, :exec_resp, ""), # Send an empty exec_resp
		     do: exec_recv({conn, cmd_id, end_id}, "") # Receive the response.
	end

	@spec exec_recv({connection, Packet.id, Packet.id}, Packet.body) :: {:ok, connection, Packet.body} | {:error, binary}
	defp exec_recv(args = {conn, cmd_id, end_id}, body) do
		case recv(conn) do
			# If the id of the packet is the same as the command we sent,
			# the packet contains the response, or part of.
			{:ok, {:exec_resp, ^cmd_id, new_body, _}} ->
				exec_recv(args, body <> new_body)
			# If the id of the packet is the same of the empty exec_resp we sent,
			# we have reached the end of the response.
			{:ok, {:exec_resp, ^end_id, _, _}} ->
				{:ok, conn, body}
			# Drop packets not that are not being tracked.
			# This is because we can block forever if you get
			# the password wrong (tested with CS:GO server Nov 2016)
			# as the second exec_resp isn't sent for some reason.
			{:ok, {:exec_resp, _, _, _}} ->
				exec_recv(args, body)
			{:ok, {bad_kind, bad_id, _, _}} ->
				{:error, unexpected_packet_error(bad_kind, bad_id)}
			{:error, err} ->
				{:error, err}
		end
	end

	@doc """
	Send a RCON packet.
	"""
	@spec send(connection, Packet.kind, Packet.body) :: {:ok, connection, Packet.id} | {:error, binary}
	def send(conn, kind, body) do
		{socket, packet_id} = conn = next_packet_id(conn)
		with {:ok, packet_raw} <- Packet.create_and_encode(kind, body, packet_id, :client),
		     :ok <- Socket.Stream.send(socket, packet_raw),
		     do: {:ok, conn, packet_id}
	end

	@doc """
	Receive a RCON packet.
	"""
	@spec recv(connection) :: {:ok, Packet.t} | {:error, binary}
	def recv(_conn = {socket, _}) do
		with {:ok, size_bytes} when is_binary(size_bytes) <- Socket.Stream.recv(socket, Packet.size_part_len),
		     {:ok, size} <- Packet.decode_size(size_bytes),
			 {:ok, payload_bytes} when is_binary(payload_bytes) <- Socket.Stream.recv(socket, size) do
			Packet.decode_payload(size, payload_bytes, :server)
		else
			# When stream recv returns nil
			{:ok, nil} ->
				{:error, @unexpected_end_of_stream_error}
			{:error, err} ->
				{:error, err}
		end
	end

	@spec next_packet_id(connection) :: connection
	defp next_packet_id({socket, current_packet_id}) do
		if current_packet_id == Packet.max_id do
			{socket, Packet.initial_id}
		else
			{socket, current_packet_id + 1}
		end
	end

	@spec unexpected_packet_error(Packet.kind, Packet.id) :: binary
	defp unexpected_packet_error(kind, id) do
		@unexpected_packet_error <> ": kind=#{kind}, id=#{id}"
	end
end