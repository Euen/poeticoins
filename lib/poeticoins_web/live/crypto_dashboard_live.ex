defmodule PoeticoinsWeb.CryptoDashboardLive do
  use PoeticoinsWeb, :live_view
  import PoeticoinsWeb.ProductHelpers
  alias PoeticoinsWeb.Router.Helpers, as: Routes

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        products: [],
        timezone: get_timezone_from_connection(socket)
      )

    {:ok, socket}
  end

  def handle_params(%{"products" => product_ids} = _params, _uri, socket) do
    IO.inspect(product_ids, label: "product_ids params")
    new_products = Enum.map(product_ids, &product_from_string/1)

    diff = List.myers_difference(socket.assigns.products, new_products)
    products_to_insert = Keyword.get_values(diff, :ins) |> List.flatten()
    products_to_remove = Keyword.get_values(diff, :del) |> List.flatten()

    socket = Enum.reduce(products_to_insert, socket, &add_product(&2, &1))

    socket = Enum.reduce(products_to_remove, socket, &remove_product(&2, &1))

    {:noreply, socket}
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  def handle_event("add-product", %{"product_id" => product_id}, socket) do
    product_ids =
      socket.assigns.products
      |> Enum.map(&to_string/1)
      |> Kernel.++([product_id])
      |> Enum.uniq()

    socket = push_patch(socket, to: Routes.live_path(socket, __MODULE__, products: product_ids))

    {:noreply, socket}
  end

  def handle_event("add-product", %{}, socket), do: {:noreply, socket}

  def handle_event("filter-product", %{"search" => search}, socket) do
    products =
      Poeticoins.available_products()
      |> Enum.filter(fn product ->
        String.downcase(product.exchange_name) =~ String.downcase(search) or
          String.downcase(product.currency_pair) =~ String.downcase(search)
      end)

    {:noreply, assign(socket, :products, products)}
  end

  def handle_event("remove-product", %{"product-id" => product_id}, socket) do
    product_ids =
      socket.assigns.products
      |> Enum.map(&to_string/1)
      |> Kernel.--([product_id])

    socket = push_patch(socket, to: Routes.live_path(socket, __MODULE__, products: product_ids))

    {:noreply, socket}
  end

  defp add_product(socket, product) do
    Poeticoins.subscribe_to_trades(product)

    update(socket, :products, &(&1 ++ [product]))
  end

  defp remove_product(socket, product) do
    Poeticoins.unsubscribe_from_trades(product)

    update(socket, :products, &(&1 -- [product]))
  end

  def handle_info({:new_trade, trade}, socket) do
    send_update(PoeticoinsWeb.ProductComponent, id: trade.product, trade: trade)
    {:noreply, socket}
  end

  defp grouped_products_by_exchange_name do
    Poeticoins.available_products()
    |> Enum.group_by(& &1.exchange_name)
  end

  defp get_timezone_from_connection(socket) do
    case get_connect_params(socket) do
      %{"timezone" => tz} when not is_nil(tz) -> tz
      _ -> "UTC"
    end
  end
end
