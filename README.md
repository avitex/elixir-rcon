[![Build Status](https://travis-ci.org/avitex/elixir-rcon.svg)](https://travis-ci.org/avitex/elixir-rcon)
[![Hex.pm](https://img.shields.io/hexpm/v/rcon.svg)](https://hex.pm/packages/rcon)
[![Hex Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/rcon)

# RCON

**Implementation of the [Source RCON Protocol](https://developer.valvesoftware.com/wiki/Source_RCON_Protocol).**  
Documentation hosted on [hexdocs](https://hexdocs.pm/rcon).

## Installation

  Add `rcon` to your list of dependencies in `mix.exs`:

  ```elixir
  def deps do
    [{:rcon, "~> 0.2.1"}]
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