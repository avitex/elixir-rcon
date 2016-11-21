defmodule RCON do
	alias RCON.Packet

	def connect(host, port) do
		with {:ok, socket} <- :gen_tcp.connect(host, port, [:binary, active: false]),
		     do: {:ok, {socket, 0}}
	end

	def authenticate(conn, password) do
		with {:ok, conn, packet_id} <- send(conn, :auth, password),
		     {:ok, _, %{type: :exec_resp, id: ^packet_id}} <- recv(conn),
		     {:ok, _, %{type: :auth_resp, id: ^packet_id}} <- recv(conn) do
			{:ok, conn}
		else
			{:ok, _, %{type: :auth_resp, id: -1}} -> {:error, "Authentication failed"}
			{:ok, _, %{type: type, id: id}} -> {:error, "Mismatched packet id (#{id}) or type (#{type})"}
			{:error, err} -> {:error, err}
		end
	end

	def exec(conn, command) do
		with {:ok, conn, cmd_id} <- send(conn, :exec, command),
		     {:ok, conn, end_id} <- send(conn, :exec_resp, ""),
		     do: exec_recv({conn, cmd_id, end_id}, "")
	end

	defp exec_recv(args = {conn, cmd_id, end_id}, body) do
		case recv(conn) do
			{:ok, new_body, %{type: :exec_resp, id: id}} ->
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
			{:ok, _, %{type: type}} -> {:error, "Unexpected packet type: #{type}"}
			{:error, err} -> {:error, err}
		end
	end

	def send(conn, type, body) do
		{socket, packet_id} = conn = increment_packet_id(conn)
		with {:ok, packet} <- Packet.create(type, body, packet_id),
		     :ok <- :gen_tcp.send(socket, packet),
		     do: {:ok, conn, packet_id}
	end

	def recv({socket, _}) do
		with {:ok, <<size :: 32-signed-integer-little>>} <- :gen_tcp.recv(socket, 4),
		     {:ok, payload} <- :gen_tcp.recv(socket, size),
		     do: Packet.parse(size, payload)
	end

	defp increment_packet_id({socket, last_packet_id}) do
		if last_packet_id == 2147483647 do
			{socket, 0}
		else
			{socket, last_packet_id + 1}
		end
	end
end
