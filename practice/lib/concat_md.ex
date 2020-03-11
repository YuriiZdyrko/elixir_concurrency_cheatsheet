defmodule Practice.ConcatMd do
  @config_file ".concat_md_config"
  @dest_file "cheatsheet.md"
  @src_dir "../theory"

  def run(src_dir \\ @src_dir),
    do:
      run(
        src_dir,
        dest(src_dir),
        config(src_dir)
      )

  def run(src_dir, dest, config) when is_binary(src_dir) and is_binary(dest) do
    config = config || File.ls!(src_dir)

    config
    |> Enum.with_index()
    |> Enum.each(fn {file, i} ->
      file_path =
        src_dir
        |> Path.join(file)

      IO.puts("Copying #{file_path}")

      next_chunk =
        file_path
        |> File.read!()
        |> String.trim_leading("#")
        |> Kernel.<>("\n******\n")

      :ok =
        File.open(dest, [:append])
        |> elem(1)
        |> IO.binwrite("## #{i + 1}." <> next_chunk)

      File.close(dest)
    end)

    IO.puts("\n" <> Path.join(@src_dir, @dest_file) <> " generated!")
  end

  def config(src_dir) do
    path =
      src_dir
      |> Path.join(@config_file)

    if File.exists?(path) do
      File.read!(path)
      |> String.split("\n", trim: true)
      |> Enum.map(&(&1 <> ".md"))
    else
      nil
    end
  end

  def dest(src_dir) do
    path = Path.join(src_dir, @dest_file)
    File.rm(path)
    File.touch!(path)
    path
  end
end
