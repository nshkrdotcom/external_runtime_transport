defmodule ExternalRuntimeTransport.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Task.Supervisor, name: ExternalRuntimeTransport.TaskSupervisor}
    ]

    Supervisor.start_link(children,
      strategy: :one_for_one,
      name: ExternalRuntimeTransport.Supervisor
    )
  end
end
