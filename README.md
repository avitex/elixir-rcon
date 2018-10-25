# RCON

**Source compatible RCON implementation**

## Installation

  Add `rcon` to your list of dependencies in `mix.exs`:
  
  ```elixir
  def deps do
    [{:rcon, "~> 0.1.0"}]
  end
  ```
## Features

  - Source compatible *(should work with CS:GO, Minecraft, etc)*
  - Supports multi-packet responses
  - Handles messages with ID counter
  - Shouldn't blow up in your face

## Usage

  ```elixir
  {:ok, conn} = RCON.Client.connect("127.0.0.1", 27084)
  {:ok, conn} = RCON.Client.authenticate(conn, "password")
  {:ok, _conn, result} = RCON.Client.exec(conn, "status")
  
  IO.inspect result
  ```