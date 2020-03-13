defmodule RCON.PacketTest do
  use ExUnit.Case

  @client_exec_payload <<
    # ID
    0x00::32-signed-integer-little,
    # Kind
    0x02::32-signed-integer-little,
    # Body
    "hello",
    # Terminator
    0x00,
    0x00
  >>

  @client_exec_packet <<byte_size(@client_exec_payload)::32-signed-integer-little>> <>
                        @client_exec_payload

  @server_auth_resp_payload <<
    # ID
    0x00::32-signed-integer-little,
    # Kind
    0x02::32-signed-integer-little,
    # Body
    "",
    # Terminator
    0x00,
    0x00
  >>

  test "encode client exec packet" do
    assert {:ok, @client_exec_packet} == RCON.Packet.create_and_encode(:exec, "hello", 0, :client)
  end

  test "decode client exec packet" do
    assert {:ok, {:exec, 0, "hello", :client}} ==
             RCON.Packet.decode_payload(
               byte_size(@client_exec_payload),
               @client_exec_payload,
               :client
             )
  end

  test "decode server auth resp packet" do
    assert {:ok, {:auth_resp, 0, "", :server}} ==
             RCON.Packet.decode_payload(
               byte_size(@server_auth_resp_payload),
               @server_auth_resp_payload,
               :server
             )
  end
end
