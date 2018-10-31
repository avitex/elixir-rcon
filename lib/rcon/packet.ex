defmodule RCON.Packet do
	@moduledoc """
	Module for handling RCON packets.
	"""

	@initial_id 0
	@auth_failed_id -1

	# Null-term string, and packet terminator
	@terminator_part <<0, 0>>

	# Packet part lengths
	@size_part_len 4
	@id_part_len 4
	@kind_part_len 4

	@max_id 2147483647
	@max_body_len 1413
	@min_size @id_part_len + @kind_part_len + byte_size(@terminator_part)

	@type t :: {kind, id, body, from}
	@type raw :: binary

	@type size :: integer
	@type id :: integer
	@type kind :: :exec | :exec_resp | :auth | :auth_resp
	@type kind_code :: 0 | 2 | 3
	@type body :: binary
	@type from :: :client | :server

	@malformed_packet_error "Malformed packet"
	@packet_body_len_error "Packet body too large"
	@bad_packet_kind_error "Bad packet kind"
	@bad_packet_kind_code_error "Bad packet kind code"
	@bad_packet_size_error "Bad packet size"

	@doc """
	Returns the length in bytes of the packet size part.
	"""
	@spec size_part_len :: integer
	def size_part_len, do: @size_part_len

	@doc """
	Returns the length in bytes of the packet id part.
	"""
	@spec id_part_len :: integer
	def id_part_len, do: @id_part_len

	@doc """
	Returns the length in bytes of the packet kind part.
	"""
	@spec kind_part_len :: integer
	def kind_part_len, do: @kind_part_len

	@doc """
	Returns the initial packet ID value.
	"""
	@spec initial_id :: id
	def initial_id, do: @initial_id

	@doc """
	Returns the packet ID used for auth failure.
	"""
	@spec auth_failed_id :: id
	def auth_failed_id, do: @auth_failed_id

	@doc """
	Returns the max possible value a packet ID may have.

	Value from signed int32 max (`2^31 - 1`).
	"""
	@spec max_id :: id
	def max_id, do: @max_id

	@doc """
	The smallest value packet size may be.
	"""
	@spec min_size :: size
	def min_size, do: @min_size

	@doc """
	Returns the maximum size a body may have.

	Minecraft only supports a request payload length of max 1446 byte.
	However some tests showed that only requests with a payload length
	of 1413 byte or lower work reliably.
	"""
	@spec max_body_len :: integer
	def max_body_len, do: @max_body_len

	@doc """
	Returns the kind for a packet.
	"""
	@spec kind(t) :: kind
	def kind(_packet = {kind, _, _, _}), do: kind

	@doc """
	Returns the ID for a packet.
	"""
	@spec id(t) :: id
	def id(_packet = {_, id, _, _}), do: id

	@doc """
	Returns the body for a packet.
	"""
	@spec body(t) :: body
	def body(_packet = {_, _, body, _}), do: body

	@doc """
	Returns the body length in bytes for a packet.

	Does not include the null character.
	"""
	@spec body_len(t) :: integer
	def body_len(_packet = {_, _, body, _}), do: byte_size(body)

	@doc """
	Returns from what side the packet was sent from.
	"""
	@spec from(t) :: from
	def from(_packet = {_, _, _, from}), do: from

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
			size = byte_size(body) + @min_size
			header = <<
				size      :: 32-signed-integer-little,
				id        :: 32-signed-integer-little,
				kind_code :: 32-signed-integer-little,
			>>
			{:ok, header <> body <> @terminator_part}
		end
	end

	@doc """
	Decodes a packet size.
	"""
	@spec decode_size(binary) :: {:ok, size} | {:error, binary}
	def decode_size(size_bytes) do
		if !is_nil(size_bytes) and byte_size(size_bytes) == @size_part_len do
			<< size :: 32-signed-integer-little >> = size_bytes
			{:ok, size}
		else
			{:error, @bad_packet_size_error}
		end
	end

	@doc """
	Decodes a packet payload from transmission.
	"""
	@spec decode_payload(size, binary, from) :: {:ok, t} | {:error, binary}
	def decode_payload(size, payload, from \\ :server) do
		body_size = size - @min_size
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
	def kind_from_code(kind_code, from)
	def kind_from_code(0, _), do: {:ok, :exec_resp}
	def kind_from_code(2, :client), do: {:ok, :exec}
	def kind_from_code(2, :server), do: {:ok, :auth_resp}
	def kind_from_code(3, _), do: {:ok, :auth}
	def kind_from_code(_, _), do: {:error, @bad_packet_kind_code_error}

	@doc """
	Returns the code for a packet kind.
	"""
	@spec kind_to_code(kind, from) :: {:ok, kind_code} | {:error, binary}
	def kind_to_code(kind, from)
	def kind_to_code(:exec_resp, _), do: {:ok, 0}
	def kind_to_code(:exec, :client), do: {:ok, 2}
	def kind_to_code(:auth_resp, :server), do: {:ok, 2}
	def kind_to_code(:auth, _), do: {:ok, 3}
	def kind_to_code(_, _), do: {:error, @bad_packet_kind_error}

	defp check_packet(packet) do
		cond do
			body_len(packet) > @max_body_len ->
				{:error, @packet_body_len_error}
			true ->
				{:ok, packet}
		end
	end
end