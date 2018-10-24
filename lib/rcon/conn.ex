defmodule RCON.Conn do
	@moduledoc """
	Represents a client connection to a server.
	"""

	alias RCON.Packet

	@type t :: {socket, Packet.id}
	@type socket :: any

	@spec new(socket) :: t
	def new(socket), do: {socket, 0}

	@doc false
	@spec socket(t) :: socket
	def socket({socket, _}), do: socket
	
	@doc false
	@spec current_packet_id(t) :: Packet.id
	def current_packet_id({_, current_packet_id}), do: current_packet_id

	@doc false
	@spec increment_packet_id(t) :: t
	def increment_packet_id({socket, current_packet_id}) do
		if current_packet_id == Packet.max_id do
			{socket, 0}
		else
			{socket, current_packet_id + 1}
		end
	end
end