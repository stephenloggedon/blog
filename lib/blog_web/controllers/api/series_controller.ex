defmodule BlogWeb.Api.SeriesController do
  use BlogWeb, :controller

  alias Blog.Content

  plug :put_view, json: BlogWeb.Api.SeriesJSON

  def index(conn, _params) do
    series = Content.list_series()
    
    conn
    |> put_status(:ok)
    |> render(:index, series: series)
  end

  def show(conn, %{"id" => id}) do
    case Content.get_series(id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> render(:error, %{message: "Series not found"})

      series ->
        conn
        |> put_status(:ok)
        |> render(:show, series: series)
    end
  end

  def create(conn, %{"series" => series_params}) do
    case Content.create_series(series_params) do
      {:ok, series} ->
        conn
        |> put_status(:created)
        |> render(:show, series: series)

      {:error, %Ecto.Changeset{}} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:error, %{message: "Invalid series data"})
    end
  end

  def update(conn, %{"id" => id, "series" => series_params}) do
    case Content.get_series(id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> render(:error, %{message: "Series not found"})

      series ->
        case Content.update_series(series, series_params) do
          {:ok, series} ->
            conn
            |> put_status(:ok)
            |> render(:show, series: series)

          {:error, %Ecto.Changeset{}} ->
            conn
            |> put_status(:unprocessable_entity)
            |> render(:error, %{message: "Invalid series data"})
        end
    end
  end

  def delete(conn, %{"id" => id}) do
    case Content.get_series(id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> render(:error, %{message: "Series not found"})

      series ->
        case Content.delete_series(series) do
          {:ok, _series} ->
            send_resp(conn, :no_content, "")

          {:error, %Ecto.Changeset{}} ->
            conn
            |> put_status(:unprocessable_entity)
            |> render(:error, %{message: "Unable to delete series"})
        end
    end
  end
end