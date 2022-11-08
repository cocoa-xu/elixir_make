defmodule Mix.Tasks.ElixirMake.Precompile do
  @shortdoc "Precompiles the given project for all targets"

  @moduledoc """
  Precompiles the given project for all targets.

  This is only supported if `make_precompiler` is specified.
  """

  alias ElixirMake.Artefact
  require Logger
  use Mix.Task

  @impl true
  def run(args) do
    config = Mix.Project.config()
    paths = config[:make_precompiler_priv_paths] || ["."]

    try do
      precompiler =
        config[:make_precompiler] ||
          Mix.raise(
            ":make_precompiler project configuration is required when using elixir_make.precompile"
          )

      targets = precompiler.all_supported_targets(:compile)

      precompiled_artefacts =
        Enum.map(targets, fn target ->
          {archived_filename, checksum_algo, checksum} =
            case precompiler.precompile(args, target) do
              :ok -> Artefact.create_precompiled_archive(config, target, paths)
              {:error, msg} -> Mix.raise(msg)
            end

          %{path: archived_filename, checksum_algo: checksum_algo, checksum: checksum}
        end)

      Artefact.write_checksum!(precompiled_artefacts)

      if function_exported?(precompiler, :post_precompile, 0) do
        precompiler.post_precompile()
      else
        :ok
      end
    after
      app_priv = Path.join(Mix.Project.app_path(config), "priv")

      for include <- paths,
          file <- Path.wildcard(Path.join(app_priv, include)) do
        File.rm_rf(file)
      end
    end
  end
end
