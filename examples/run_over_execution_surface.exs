alias ExternalRuntimeTransport.Command
alias ExternalRuntimeTransport.Transport

{:ok, local_result} =
  Transport.run(Command.new("sh", ["-c", "printf local-ready"]))

IO.puts("local stdout: #{local_result.stdout}")

# To move the same command onto SSH, change only `execution_surface`.
#
# {:ok, remote_result} =
#   Transport.run(
#     Command.new("hostname"),
#     execution_surface: [
#       surface_kind: :ssh_exec,
#       transport_options: [
#         destination: "buildbox.example",
#         ssh_user: "deploy",
#         port: 22
#       ]
#     ]
#   )
#
# IO.puts("remote stdout: #{remote_result.stdout}")
