defmodule ExternalRuntimeTransport.Command do
  @moduledoc """
  Generic transport-level command invocation.

  This struct stays below CLI-domain concerns. It only carries the executable,
  argv, and launch-time process options needed by the execution-surface
  substrate.
  """

  @enforce_keys [:command]
  defstruct command: nil, args: [], cwd: nil, env: %{}, clear_env?: false, user: nil

  @type env_key :: String.t()
  @type env_value :: String.t()
  @type env_map :: %{optional(env_key()) => env_value()}
  @type user :: String.t() | nil

  @type t :: %__MODULE__{
          command: String.t(),
          args: [String.t()],
          cwd: String.t() | nil,
          env: env_map(),
          clear_env?: boolean(),
          user: user()
        }

  @doc """
  Builds a normalized transport command.
  """
  @spec new(String.t(), [String.t()] | keyword(), keyword()) :: t()
  def new(command, args \\ [], opts \\ [])
      when is_binary(command) and is_list(args) and is_list(opts) do
    {args, opts} =
      if opts == [] and keyword_list?(args) do
        {[], args}
      else
        {args, opts}
      end

    %__MODULE__{
      command: command,
      args: args,
      cwd: Keyword.get(opts, :cwd),
      env: normalize_env(Keyword.get(opts, :env, %{})),
      clear_env?: Keyword.get(opts, :clear_env?, false),
      user: normalize_user(Keyword.get(opts, :user))
    }
  end

  @doc """
  Returns the executable and argv as a flat list.
  """
  @spec argv(t()) :: [String.t()]
  def argv(%__MODULE__{} = command) do
    [command.command | command.args]
  end

  @doc """
  Adds or replaces one environment variable.
  """
  @spec put_env(t(), String.t() | atom(), String.t() | atom() | number() | boolean()) :: t()
  def put_env(%__MODULE__{} = command, key, value) do
    merge_env(command, %{normalize_env_key(key) => normalize_env_value(value)})
  end

  @doc """
  Merges environment variables into the invocation.
  """
  @spec merge_env(t(), map()) :: t()
  def merge_env(%__MODULE__{} = command, env) when is_map(env) do
    %{command | env: Map.merge(command.env, normalize_env(env))}
  end

  @doc """
  Validates the generic transport command contract.
  """
  @spec validate(t()) ::
          :ok
          | {:error, {:invalid_command, term()}}
          | {:error, {:invalid_args, term()}}
          | {:error, {:invalid_cwd, term()}}
          | {:error, {:invalid_env, term()}}
          | {:error, {:invalid_clear_env, term()}}
          | {:error, {:invalid_user, term()}}
  def validate(%__MODULE__{
        command: command,
        args: args,
        cwd: cwd,
        env: env,
        clear_env?: clear_env?,
        user: user
      }) do
    validators = [
      fn -> validate_command(command) end,
      fn -> validate_args(args) end,
      fn -> validate_cwd(cwd) end,
      fn -> validate_env(env) end,
      fn -> validate_clear_env(clear_env?) end,
      fn -> validate_user(user) end
    ]

    Enum.reduce_while(validators, :ok, fn validator, :ok ->
      case validator.() do
        :ok -> {:cont, :ok}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  defp normalize_env(env) when is_map(env) do
    Map.new(env, fn {key, value} ->
      {normalize_env_key(key), normalize_env_value(value)}
    end)
  end

  defp normalize_env(_other), do: %{}

  defp normalize_env_key(key) when is_binary(key), do: key
  defp normalize_env_key(key) when is_atom(key), do: Atom.to_string(key)
  defp normalize_env_key(key), do: to_string(key)

  defp normalize_env_value(value) when is_binary(value), do: value
  defp normalize_env_value(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_env_value(value) when is_boolean(value), do: to_string(value)
  defp normalize_env_value(value) when is_integer(value), do: Integer.to_string(value)
  defp normalize_env_value(value) when is_float(value), do: Float.to_string(value)

  defp validate_command(command) when is_binary(command) and command != "", do: :ok
  defp validate_command(command), do: {:error, {:invalid_command, command}}

  defp validate_args(args) when is_list(args) do
    if Enum.all?(args, &is_binary/1) do
      :ok
    else
      {:error, {:invalid_args, args}}
    end
  end

  defp validate_args(args), do: {:error, {:invalid_args, args}}

  defp validate_cwd(nil), do: :ok
  defp validate_cwd(cwd) when is_binary(cwd), do: :ok
  defp validate_cwd(cwd), do: {:error, {:invalid_cwd, cwd}}

  defp validate_env(env) when is_map(env) do
    if Enum.all?(env, fn {key, value} -> is_binary(key) and is_binary(value) end) do
      :ok
    else
      {:error, {:invalid_env, env}}
    end
  end

  defp validate_env(env), do: {:error, {:invalid_env, env}}

  defp validate_clear_env(value) when is_boolean(value), do: :ok
  defp validate_clear_env(value), do: {:error, {:invalid_clear_env, value}}

  defp validate_user(nil), do: :ok
  defp validate_user(user) when is_binary(user) and user != "", do: :ok
  defp validate_user(user), do: {:error, {:invalid_user, user}}

  defp normalize_user(nil), do: nil
  defp normalize_user(user) when is_binary(user), do: user
  defp normalize_user(user) when is_atom(user), do: Atom.to_string(user)
  defp normalize_user(user), do: to_string(user)

  defp keyword_list?(list) when is_list(list), do: Keyword.keyword?(list)
  defp keyword_list?(_other), do: false
end
