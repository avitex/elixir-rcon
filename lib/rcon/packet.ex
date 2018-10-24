defmodule RCON.Packet do
	@moduledoc """
	Module for handling RCON packets.
	"""

	# Constant sizes.
	@header_part_size 8
	@terminator_part_size 2

	# Minecraft only supports a request payload length of max 1446 byte.
	# However some tests showed that only requests with a payload length
	# of 1413 byte or lower work reliably.
	@max_body_size 1413

	# Max ID value a packet may have (signed int32, 2^31 - 1)
	@max_id 2147483647

	# Initial packet ID
	@initial_id 0

	# Null-term string, and packet terminator
	@terminator_part <<0, 0>>

	@type t :: {kind, id, body, from}
	@type raw :: binary

	@type id :: integer
	@type kind :: :exec | :exec_resp | :auth | :auth_resp
	@type kind_code :: 0 | 2 | 3
	@type body :: binary
	@type from :: :client | :server

	@malformed_packet_error "Malformed packet"
	@packet_body_size_error "Packet body too large"
	@bad_packet_kind_error "Bad packet kind"
	@bad_packet_kind_code_error "Bad packet kind code"

	@doc """
	Returns the max possible value a packet ID may have.
	"""
	@spec max_id :: integer
	def max_id, do: @max_id

	@doc """
	Returns the kind for a packet.
	"""
	@spec kind(t) :: kind
	def kind({kind, _, _, _}), do: kind

	@doc """
	Returns the ID for a packet.
	"""
	@spec id(t) :: id
	def id({_, id, _, _}), do: id

	@doc """
	Returns the body for a packet.
	"""
	@spec body(t) :: body
	def body({_, _, body, _}), do: body

	@doc """
	Returns the body size for a packet.
	"""
	@spec body_size(t) :: integer
	def body_size({_, body, _, _}), do: byte_size(body)

	@doc """
	Returns from what side the packet was sent from.
	"""
	@spec from(t) :: from
	def from({_, _, _, from}), do: from

	@doc """
	Creates and encodes a packet in one step.
	"""
	@spec create_and_encode(kind, body, id, from) :: {:ok, raw} | {:error, binary}
	def create_and_encode(kind, body, id \\ @initial_id, from \\ :client) do
		encode({kind, id, body, from})
	end

	@doc """
	Creates a packet.
	"""
	@spec create(kind, body, id, from) :: {:ok, t} | {:error, binary}
	def create(kind, body, id \\ @initial_id, from \\ :client) do
		check_packet({kind, id, body, from})
	end

	@doc """
	Encodes a packet to a binary for transmission.
	"""
	@spec encode(t) :: {:ok, raw} | {:error, binary}
	def encode(packet) do
		with {:ok, {kind, id, body, from}} <- check_packet(packet),
		     {:ok, kind_code} <- kind_to_code(kind, from) do
			size = @header_part_size + byte_size(body) + @terminator_part_size
			header = <<
				size      :: 32-signed-integer-little,
				id        :: 32-signed-integer-little,
				kind_code :: 32-signed-integer-little,
			>>
			{:ok, header <> body <> @terminator_part}
		end
	end

	@doc """
	Decodes a packet from transmission.
	"""
	@spec decode(integer, binary, from) :: {:ok, t} | {:error, binary}
	def decode(size, payload, from \\ :server) do
		body_size = size - @header_part_size - @terminator_part_size
		case payload do
			<<
				id        :: 32-signed-integer-little,
				kind_code :: 32-signed-integer-little,
				body      :: binary-size(body_size),
			>> <> @terminator_part ->
				with {:ok, kind} <- kind_from_code(kind_code, from) do
					{:ok, {kind, id, body, from}}
				end
			_ -> {:error, @malformed_packet_error}
		end
	end

	@doc """
	Returns the packet kind for a code.
	"""
	@spec kind_from_code(kind_code, from) :: {:ok, kind} | {:error, binary}
	def kind_from_code(0, _), do: {:ok, :exec_resp}
	def kind_from_code(2, :client), do: {:ok, :exec}
	def kind_from_code(2, :server), do: {:ok, :auth_resp}
	def kind_from_code(3, _), do: {:ok, :auth}
	def kind_from_code(_, _), do: {:error, @bad_packet_kind_code_error}

	@doc """
	Returns the code for a packet kind.
	"""
	@spec kind_to_code(kind, from) :: {:ok, kind_code} | {:error, binary}
	def kind_to_code(:exec_resp, _), do: {:ok, 0}
	def kind_to_code(:auth_resp, :client), do: {:ok, 2}
	def kind_to_code(:exec, :server), do: {:ok, 2}
	def kind_to_code(:auth, _), do: {:ok, 3}
	def kind_to_code(_, _), do: {:error, @bad_packet_kind_error}

	defp check_packet(packet) do
		cond do
			body_size(packet) > @max_body_size ->
				{:error, @packet_body_size_error}
			true ->
				{:ok, packet}
		end
	end
end