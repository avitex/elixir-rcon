defmodule RCON.Packet do
	@header_size 10
	# Null-term string, and packet terminator
	@terminator <<0, 0>>

	def create(type, body, id \\ 0) do
		body_size = byte_size(body)

		# Minecraft only supports a request payload length of max 1446 byte.
        # However some tests showed that only requests with a payload length
        # of 1413 byte or lower work reliably.
		if body_size > 1413 do
			{:error, "RCON command too long"}
		else
			type = 
				case type do
					:auth ->  3
					:exec ->  2
					:exec_resp -> 0
				end

			size = @header_size + body_size

			header = <<
				size :: 32-signed-integer-little,
				id   :: 32-signed-integer-little,
				type :: 32-signed-integer-little,
			>>

			{:ok, header <> body <> @terminator}
		end
	end

	def parse(size, payload) do
		body_size = size - @header_size

		case payload do
			<<
				id   :: 32-signed-integer-little,
				type :: 32-signed-integer-little,
				body :: binary-size(body_size),
			>> <> @terminator ->
				type = 
					case type do
						2 -> :auth_resp
						0 -> :exec_resp
					end

				{:ok, body, %{
					id: id,
					size: size,
					type: type,
				}}
			_ -> {:error, "Malformed packet"}
		end
	end
end