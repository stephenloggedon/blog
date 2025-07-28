defmodule BlogWeb.Api.SeriesJSON do
  alias Blog.Content.Series

  @doc """
  Renders a list of series.
  """
  def index(%{series: series}) do
    %{data: for(s <- series, do: data(s))}
  end

  @doc """
  Renders a single series.
  """
  def show(%{series: series}) do
    %{data: data(series)}
  end

  def error(%{message: message}) do
    %{message: message}
  end

  defp data(%Series{} = series) do
    %{
      id: series.id,
      title: series.title,
      description: series.description,
      slug: series.slug,
      inserted_at: series.inserted_at,
      updated_at: series.updated_at
    }
  end
end
