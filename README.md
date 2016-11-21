# RCON

**Source compatible RCON implementation**

## Installation

  Add `rcon` to your list of dependencies in `mix.exs`:
  
  ```elixir
  def deps do
    [{:rcon, "~> 0.1.0"}]
  end
  ```

## Usage

  ```elixir
  {:ok, conn} = RCON.connect({10, 0, 0, 1}, 27084)
  {:ok, conn} = RCON.authenticate(conn, "password")
  {:ok, _conn, result} = RCON.exec(conn, "status")
  IO.inspect result
  ```

## TODO
- Add tests and documentation