defmodule RCON do
	@moduledoc """
	
	"""

	alias RCON.Conn
	alias RCON.Packet

	@type srv_addr :: any
	@type srv_port :: 0..65535

	@auth_failed_id -1

	@auth_failed_error "Authentication failed"
	@unexpected_kind_error "Unexpected packet kind"
	@unexpected_packet_error "Unexpected packet ID or kind"

	@doc """
	Connects to an RCON server.
	"""
	@spec connect(srv_addr, srv_port) :: Conn.t
	def connect(srv_addr, srv_port) do
		with {:ok, socket} <- :gen_tcp.connect(srv_addr, srv_port, [:binary, active: false]),
		     do: {:ok, Conn.new(socket)}
	end

	@doc """
	Authenticate a connection given a password.
	"""
	@spec authenticate(Conn.t, binary) :: {:ok, Conn.t} | {:error, binary}
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
	@spec exec(Conn.t, binary) :: {:ok, Conn.t, binary} | {:error, binary}
	def exec(conn, command) do
		with {:ok, conn, cmd_id} <- send(conn, :exec, command),
		     {:ok, conn, end_id} <- send(conn, :exec_resp, ""),
		     do: exec_recv({conn, cmd_id, end_id}, "")
	end

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
	@spec send(Conn.t, Packet.kind, Packet.body) :: {:ok, Conn.t, Packet.id} | {:error, binary}
	def send(conn, kind, body) do
		conn = Conn.increment_packet_id(conn)
		packet_id = Conn.current_packet_id(conn)
		with {:ok, packet} <- Packet.create_and_encode(kind, packet_id, body, :client),
		     :ok <- :gen_tcp.send(Conn.socket(conn), packet),
		     do: {:ok, conn, packet_id}
	end

	@doc """
	Receive a RCON packet.
	"""
	@spec recv(Conn.t) :: {:ok, Packet.t} | {:error, binary}
	def recv(conn) do
		socket = Conn.socket(conn)
		with {:ok, << size :: 32-signed-integer-little >>} <- :gen_tcp.recv(socket, 4),
		     {:ok, payload} <- :gen_tcp.recv(socket, size),
		     do: Packet.decode(size, payload, :server)
	end
end
