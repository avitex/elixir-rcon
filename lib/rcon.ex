defmodule RCON do
  @moduledoc false

  defmodule Error do
    defexception message: nil
    @type t :: %__MODULE__{message: String.t() | nil}
  end
end
