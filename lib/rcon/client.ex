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

	@auth_failed_error "Authentication failed"
	@unexpected_kind_error "Unexpected packet kind"
	@unexpected_packet_error "Unexpected packet ID or kind"

	@doc """
	Connects to an RCON server.
	"""
	@spec connect(Socket.Address.t, :inet.port_number, options) :: {:ok, connection} | {:error, Socket.Error.t}
	def connect(address, port, options \\ []) do
		timeout = Keyword.get(options, :timeout, :infinity)
		with {:ok, socket} <- Socket.TCP.connect(address, port, [:binary, active: false, timeout: timeout]) do
			{:ok, {socket, Packet.initial_id}}
		end
	end

	@doc """
	Authenticate a connection given a password.
	"""
	@spec authenticate(connection, binary) :: {:ok, connection} | {:error, binary}
	def authenticate(conn, password) do
		with {:ok, conn, packet_id} <- send(conn, :auth, password),
		     {:ok, _, {:exec_resp, ^packet_id, _, _}} <- recv(conn),
		     {:ok, _, {:auth_resp, ^packet_id, _, _}} <- recv(conn) do
			{:ok, conn}
		else
			{:ok, _, {:auth_resp, @auth_failed_id}} -> {:error, @auth_failed_error}
			{:ok, _, {bad_kind, bad_id}} -> {:error, @unexpected_packet_error <> ": #{bad_id}, #{bad_kind}"}
			{:error, err} -> {:error, err}
		end
	end

	@doc """
	Execute a command.
	"""
	@spec exec(connection, binary) :: {:ok, connection, binary} | {:error, binary}
	def exec(conn, command) do
		with {:ok, conn, cmd_id} <- send(conn, :exec, command),
		     {:ok, conn, end_id} <- send(conn, :exec_resp, ""),
		     do: exec_recv({conn, cmd_id, end_id}, "")
	end

	@spec exec_recv({connection, Packet.id, Packet.id}, Packet.body)
	defp exec_recv(args = {conn, cmd_id, end_id}, body) do
		case recv(conn) do
			{:ok, {:exec_resp, id, new_body, _}} ->
				cond do
					id == cmd_id -> exec_recv(args, body <> new_body)
					id == end_id -> {:ok, conn, body}
					# Drop packets not that are not being tracked.
					# This is because we can block forever if you get
					# the password wrong (tested with CS:GO server Nov 2016)
					# as the second exec_resp isn't sent for some reason.
					# https://developer.valvesoftware.com/wiki/Source_RCON_Protocol#Multiple-packet_Responses
					true -> exec_recv(args, body)
				end
			{:ok, {kind, _, _, _}} ->
				{:error, @unexpected_kind_error <> ": #{kind}"}
			{:error, err} ->
				{:error, err}
		end
	end

	@doc """
	Send a RCON packet.
	"""
	@spec send(connection, Packet.kind, Packet.body) :: {:ok, connection, Packet.id} | {:error, binary}
	def send(conn, kind, body) do
		{socket, packet_id} = conn = increment_packet_id(conn)
		with {:ok, packet_raw} <- Packet.create_and_encode(kind, packet_id, body, :client),
		     :ok <- Socket.Stream.send(socket, packet_raw),
		     do: {:ok, conn, packet_id}
	end

	@doc """
	Receive a RCON packet.
	"""
	@spec recv(connection) :: {:ok, Packet.t} | {:error, binary}
	def recv({socket, _}) do
		with {:ok, size_bytes} <- Socket.Stream.recv(socket, Packet.size_part_len),
		     {:ok, size} <- Packet.decode_size(size_bytes),
		     {:ok, payload} <- Socket.Stream.recv(socket, size),
		     do: Packet.decode_payload(size, payload, :server)
	end

	@spec increment_packet_id(connection) :: connection
	defp increment_packet_id({socket, current_packet_id}) do
		if current_packet_id == Packet.max_id do
			{socket, Packet.initial_id}
		else
			{socket, current_packet_id + 1}
		end
	end
end