defmodule BlogWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  At first glance, this module may seem daunting, but its goal is to provide
  core building blocks for your application, such as modals, tables, and
  forms. The components consist mostly of markup and are well-documented
  with doc strings and declarative assigns. You may customize and style
  them in any way you want, based on your application growth and needs.

  The default components use Tailwind CSS, a utility-first CSS framework.
  See the [Tailwind CSS documentation](https://tailwindcss.com) to learn
  how to customize them or feel free to swap in another framework altogether.

  Icons are provided by [heroicons](https://heroicons.com). See `icon/1` for usage.
  """
  use Phoenix.Component

  alias Phoenix.HTML.Form
  alias Phoenix.LiveView.JS
  use Gettext, backend: BlogWeb.Gettext

  @doc """
  Renders a modal.

  ## Examples

      <.modal id="confirm-modal">
        This is a modal.
      </.modal>

  JS commands may be passed to the `:on_cancel` to configure
  the closing/cancel event, for example:

      <.modal id="confirm" on_cancel={JS.navigate(~p"/posts")}>
        This is another modal.
      </.modal>

  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_cancel, JS, default: %JS{}
  slot :inner_block, required: true

  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@show && show_modal(@id)}
      phx-remove={hide_modal(@id)}
      data-cancel={JS.exec(@on_cancel, "phx-remove")}
      class="relative z-50 hidden"
    >
      <div id={"#{@id}-bg"} class="bg-zinc-50/90 fixed inset-0 transition-opacity" aria-hidden="true" />
      <div
        class="fixed inset-0 overflow-y-auto"
        aria-labelledby={"#{@id}-title"}
        aria-describedby={"#{@id}-description"}
        role="dialog"
        aria-modal="true"
        tabindex="0"
      >
        <div class="flex min-h-full items-center justify-center">
          <div class="w-full max-w-3xl p-4 sm:p-6 lg:py-8">
            <.focus_wrap
              id={"#{@id}-container"}
              phx-window-keydown={JS.exec("data-cancel", to: "##{@id}")}
              phx-key="escape"
              phx-click-away={JS.exec("data-cancel", to: "##{@id}")}
              class="shadow-zinc-700/10 ring-zinc-700/10 relative hidden rounded-2xl bg-white p-14 shadow-lg ring-1 transition"
            >
              <div class="absolute top-6 right-5">
                <button
                  phx-click={JS.exec("data-cancel", to: "##{@id}")}
                  type="button"
                  class="-m-3 flex-none p-3 opacity-20 hover:opacity-40"
                  aria-label={gettext("close")}
                >
                  <.icon name="hero-x-mark-solid" class="h-5 w-5" />
                </button>
              </div>
              <div id={"#{@id}-content"}>
                {render_slot(@inner_block)}
              </div>
            </.focus_wrap>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:info} phx-mounted={show("#flash")}>Welcome Back!</.flash>
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class={[
        "fixed top-2 right-2 mr-2 w-80 sm:w-96 z-50 rounded-lg p-3 ring-1",
        @kind == :info && "bg-emerald-50 text-emerald-800 ring-emerald-500 fill-cyan-900",
        @kind == :error && "bg-rose-50 text-rose-900 shadow-md ring-rose-500 fill-rose-900"
      ]}
      {@rest}
    >
      <p :if={@title} class="flex items-center gap-1.5 text-sm font-semibold leading-6">
        <.icon :if={@kind == :info} name="hero-information-circle-mini" class="h-4 w-4" />
        <.icon :if={@kind == :error} name="hero-exclamation-circle-mini" class="h-4 w-4" />
        {@title}
      </p>
      <p class="mt-2 text-sm leading-5">{msg}</p>
      <button type="button" class="group absolute top-1 right-1 p-2" aria-label={gettext("close")}>
        <.icon name="hero-x-mark-solid" class="h-5 w-5 opacity-40 group-hover:opacity-70" />
      </button>
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id}>
      <.flash kind={:info} title={gettext("Success!")} flash={@flash} />
      <.flash kind={:error} title={gettext("Error!")} flash={@flash} />
      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error")}
        phx-connected={hide("#client-error")}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 h-3 w-3 animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error")}
        phx-connected={hide("#server-error")}
        hidden
      >
        {gettext("Hang in there while we get back on track")}
        <.icon name="hero-arrow-path" class="ml-1 h-3 w-3 animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Renders a simple form.

  ## Examples

      <.simple_form for={@form} phx-change="validate" phx-submit="save">
        <.input field={@form[:email]} label="Email"/>
        <.input field={@form[:username]} label="Username" />
        <:actions>
          <.button>Save</.button>
        </:actions>
      </.simple_form>
  """
  attr :for, :any, required: true, doc: "the datastructure for the form"
  attr :as, :any, default: nil, doc: "the server side parameter to collect all input under"

  attr :rest, :global,
    include: ~w(autocomplete name rel action enctype method novalidate target multipart),
    doc: "the arbitrary HTML attributes to apply to the form tag"

  slot :inner_block, required: true
  slot :actions, doc: "the slot for form actions, such as a submit button"

  def simple_form(assigns) do
    ~H"""
    <.form :let={f} for={@for} as={@as} {@rest}>
      <div class="mt-10 space-y-8 bg-white">
        {render_slot(@inner_block, f)}
        <div :for={action <- @actions} class="mt-2 flex items-center justify-between gap-6">
          {render_slot(action, f)}
        </div>
      </div>
    </.form>
    """
  end

  @doc """
  Renders a button.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" class="ml-2">Send!</.button>
  """
  attr :type, :string, default: nil
  attr :class, :string, default: nil
  attr :rest, :global, include: ~w(disabled form name value)

  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        "phx-submit-loading:opacity-75 rounded-lg bg-zinc-900 hover:bg-zinc-700 py-2 px-3",
        "text-sm font-semibold leading-6 text-white active:text-white/80",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Types

  This function accepts all HTML input types, considering that:

    * You may also set `type="select"` to render a `<select>` tag

    * `type="checkbox"` is used exclusively to render boolean values

    * For live file uploads, see `Phoenix.Component.live_file_input/1`

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information. Unsupported types, such as hidden and radio,
  are best written directly in your templates.

  ## Examples

      <.input field={@form[:email]} type="email" />
      <.input name="my-input" errors={["oh no!"]} />
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               range search select tel text textarea time url week)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  slot :inner_block

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(field.errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div phx-feedback-for={@name}>
      <label class="flex items-center gap-4 text-sm leading-6 text-zinc-600">
        <input type="hidden" name={@name} value="false" />
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          class="rounded border-zinc-300 text-zinc-900 focus:ring-0"
          {@rest}
        />
        {@label}
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div phx-feedback-for={@name}>
      <.label for={@id}>{@label}</.label>
      <select
        id={@id}
        name={@name}
        class="mt-2 block w-full rounded-md border border-gray-300 bg-white shadow-sm focus:border-zinc-400 focus:ring-0 sm:text-sm"
        multiple={@multiple}
        {@rest}
      >
        <option :if={@prompt} value="">{@prompt}</option>
        {Phoenix.HTML.Form.options_for_select(@options, @value)}
      </select>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div phx-feedback-for={@name}>
      <.label for={@id}>{@label}</.label>
      <textarea
        id={@id}
        name={@name}
        class={[
          "mt-2 block w-full rounded-lg text-zinc-900 focus:ring-0 sm:text-sm sm:leading-6",
          "min-h-[6rem] phx-no-feedback:border-zinc-300 phx-no-feedback:focus:border-zinc-400",
          @errors == [] && "border-zinc-300 focus:border-zinc-400",
          @errors != [] && "border-rose-400 focus:border-rose-400"
        ]}
        {@rest}
      ><%= Phoenix.HTML.Form.normalize_value("textarea", @value) %></textarea>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    ~H"""
    <div phx-feedback-for={@name}>
      <.label for={@id}>{@label}</.label>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        class={[
          "mt-2 block w-full rounded-lg text-zinc-900 focus:ring-0 sm:text-sm sm:leading-6",
          "phx-no-feedback:border-zinc-300 phx-no-feedback:focus:border-zinc-400",
          @errors == [] && "border-zinc-300 focus:border-zinc-400",
          @errors != [] && "border-rose-400 focus:border-rose-400"
        ]}
        {@rest}
      />
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  @doc """
  Renders a label.
  """
  attr :for, :string, default: nil
  slot :inner_block, required: true

  def label(assigns) do
    ~H"""
    <label for={@for} class="block text-sm font-semibold leading-6 text-zinc-800">
      {render_slot(@inner_block)}
    </label>
    """
  end

  @doc """
  Generates a generic error message.
  """
  slot :inner_block, required: true

  def error(assigns) do
    ~H"""
    <p class="mt-3 flex gap-3 text-sm leading-6 text-rose-600 phx-no-feedback:hidden">
      <.icon name="hero-exclamation-circle-mini" class="mt-0.5 h-5 w-5 flex-none" />
      {render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  Renders a header with title.
  """
  attr :class, :string, default: nil

  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={[@actions != [] && "flex items-center justify-between gap-6", @class]}>
      <div>
        <h1 class="text-lg font-semibold leading-8 text-zinc-800">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="mt-2 text-sm leading-6 text-zinc-600">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div class="flex-none">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc ~S"""
  Renders a table with generic styling.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id"><%= user.id %></:col>
        <:col :let={user} label="username"><%= user.username %></:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <div class="overflow-y-auto px-4 sm:overflow-visible sm:px-0">
      <table class="w-[40rem] mt-11 sm:w-full">
        <thead class="text-sm text-left leading-6 text-zinc-500">
          <tr>
            <th :for={col <- @col} class="p-0 pb-4 pr-6 font-normal">{col[:label]}</th>
            <th :if={@action != []} class="relative p-0 pb-4">
              <span class="sr-only">{gettext("Actions")}</span>
            </th>
          </tr>
        </thead>
        <tbody
          id={@id}
          phx-update={match?(%Phoenix.LiveView.LiveStream{}, @rows) && "stream"}
          class="relative divide-y divide-zinc-100 border-t border-zinc-200 text-sm leading-6 text-zinc-700"
        >
          <tr :for={row <- @rows} id={@row_id && @row_id.(row)} class="group hover:bg-zinc-50">
            <td
              :for={{col, i} <- Enum.with_index(@col)}
              phx-click={@row_click && @row_click.(row)}
              class={["relative p-0", @row_click && "hover:cursor-pointer"]}
            >
              <div class="block py-4 pr-6">
                <span class="absolute -inset-y-px right-0 -left-4 group-hover:bg-zinc-50 sm:rounded-l-xl" />
                <span class={["relative", i == 0 && "font-semibold text-zinc-900"]}>
                  {render_slot(col, @row_item.(row))}
                </span>
              </div>
            </td>
            <td :if={@action != []} class="relative w-14 p-0">
              <div class="relative whitespace-nowrap py-4 text-right text-sm font-medium">
                <span class="absolute -inset-y-px -right-4 left-0 group-hover:bg-zinc-50 sm:rounded-r-xl" />
                <span
                  :for={action <- @action}
                  class="relative ml-4 font-semibold leading-6 text-zinc-900 hover:text-zinc-700"
                >
                  {render_slot(action, @row_item.(row))}
                </span>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  @doc """
  Renders a data list.

  ## Examples

      <.list>
        <:item title="Title"><%= @post.title %></:item>
        <:item title="Views"><%= @post.views %></:item>
      </.list>
  """
  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <div class="mt-14">
      <dl class="-my-4 divide-y divide-zinc-100">
        <div :for={item <- @item} class="flex gap-4 py-4 text-sm leading-6 sm:gap-8">
          <dt class="w-1/4 flex-none text-zinc-500">{item.title}</dt>
          <dd class="text-zinc-700">{render_slot(item)}</dd>
        </div>
      </dl>
    </div>
    """
  end

  @doc """
  Renders a back navigation link.

  ## Examples

      <.back navigate={~p"/posts"}>Back to posts</.back>
  """
  attr :navigate, :any, required: true
  slot :inner_block, required: true

  def back(assigns) do
    ~H"""
    <div class="mt-16">
      <.link
        navigate={@navigate}
        class="text-sm font-semibold leading-6 text-zinc-900 hover:text-zinc-700"
      >
        <.icon name="hero-arrow-left-solid" class="h-3 w-3" />
        {render_slot(@inner_block)}
      </.link>
    </div>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are extracted from the `deps/heroicons` directory and bundled within
  your compiled app.css by the plugin in your `assets/tailwind.config.js`.

  ## Examples

      <.icon name="hero-x-mark-solid" />
      <.icon name="hero-arrow-path" class="ml-1 w-3 h-3 animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :string, default: nil

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      transition:
        {"transition-all transform ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all transform ease-in duration-200",
         "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  def show_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.show(to: "##{id}")
    |> JS.show(
      to: "##{id}-bg",
      transition: {"transition-all transform ease-out duration-300", "opacity-0", "opacity-100"}
    )
    |> show("##{id}-container")
    |> JS.add_class("overflow-hidden", to: "body")
    |> JS.focus_first(to: "##{id}-content")
  end

  def hide_modal(js \\ %JS{}, id) do
    js
    |> JS.hide(
      to: "##{id}-bg",
      transition: {"transition-all transform ease-in duration-200", "opacity-100", "opacity-0"}
    )
    |> hide("##{id}-container")
    |> JS.hide(to: "##{id}", transition: {"block", "block", "hidden"})
    |> JS.remove_class("overflow-hidden", to: "body")
    |> JS.pop_focus()
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated
    # dynamically, so we need to translate them by calling Gettext
    # with our gettext backend as first argument. Translations are
    # available in the errors.po file (as we use the "errors" domain).
    if count = opts[:count] do
      Gettext.dngettext(BlogWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(BlogWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end

  @doc """
  Renders the page header with title only.
  """
  attr :page_title, :string, required: true

  def page_header(assigns) do
    ~H"""
    <header class="bg-surface0 border-b border-surface1 w-full">
      <div class="w-full px-6 py-6">
        <h1 class="text-4xl font-bold text-text text-center">
          {@page_title}
        </h1>
      </div>
    </header>
    """
  end

  @doc """
  Renders the navigation bar adjacent to content.
  """
  attr :current_user, :map, default: nil
  attr :top_tags, :list, default: []
  attr :available_tags, :list, default: []
  attr :selected_tags, :list, default: []
  attr :available_series, :list, default: []
  attr :selected_series, :string, default: nil
  attr :search_query, :string, default: ""
  attr :search_suggestions, :list, default: []

  def content_nav(assigns) do
    ~H"""
    <nav class="flex flex-col h-full border-r border-surface1" style="width: 30%">
      <div class="p-6 border-b border-surface1">
        <div class="relative mb-4">
          <div class="rounded-lg focus-within:border-blue transition-colors">
            <form phx-submit="search" class="relative">
              <input
                type="text"
                name="query"
                value={@search_query}
                placeholder="Search posts and/or filter by tags..."
                class="w-full bg-transparent text-text placeholder-subtext0 focus:outline-none text-sm"
                phx-keyup="search_input"
                phx-debounce="300"
                autocomplete="off"
              />
            </form>
            <%= if @search_query != "" && @search_suggestions != [] do %>
              <div class="absolute z-10 w-full mt-1 bg-surface0 border border-surface1 rounded-lg shadow-lg max-h-40 overflow-y-auto">
                <%= for suggestion <- @search_suggestions do %>
                  <button
                    type="button"
                    phx-click="add_tag_from_search"
                    phx-value-tag={suggestion}
                    class="w-full text-left px-3 py-2 text-sm text-text hover:bg-surface1 transition-colors flex items-center gap-2"
                  >
                    <span class="w-4 h-4 bg-blue/20 rounded-full flex items-center justify-center">
                      <span class="w-2 h-2 bg-blue rounded-full"></span>
                    </span>
                    {suggestion}
                  </button>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>

        <div>
          <div class="mb-4 text-center">
            <div class="text-2xl font-bold text-text">
              {length(@available_tags)} tags
            </div>
            <div class="text-xs text-subtext1">Available</div>
          </div>

          <div class="flex items-center justify-between mb-3">
            <h3 class="text-sm font-medium text-text">Popular Tags</h3>
            <%= if @selected_tags != [] do %>
              <button
                phx-click="clear_filters"
                class="text-xs text-subtext0 hover:text-text transition-colors px-2 py-1 hover:bg-surface0 rounded"
              >
                Clear
              </button>
            <% end %>
          </div>

          <div class="flex flex-wrap gap-2 mb-4">
            <%= for tag <- @top_tags do %>
              <button
                phx-click="toggle_tag"
                phx-value-tag={tag}
                class={[
                  "px-3 py-1 text-xs rounded-full border transition-all duration-200 hover:scale-105",
                  if(tag in @selected_tags,
                    do: "border-blue text-white bg-blue",
                    else: "border-surface2 text-subtext1 hover:border-blue/50 hover:text-blue"
                  )
                ]}
              >
                {tag}
              </button>
            <% end %>
          </div>

          <%= if Enum.any?(@selected_tags, fn tag -> tag not in @top_tags end) do %>
            <div class="mb-4">
              <h4 class="text-xs font-medium text-subtext1 mb-2">Additional Tags</h4>
              <div class="flex flex-wrap gap-2">
                <%= for tag <- @selected_tags, tag not in @top_tags do %>
                  <button
                    phx-click="toggle_tag"
                    phx-value-tag={tag}
                    class="px-3 py-1 text-xs rounded-full border border-blue text-white bg-blue transition-all duration-200 hover:scale-105"
                  >
                    {tag}
                  </button>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>

        <%= if @available_series != [] do %>
          <div class="-mx-6 border-t border-surface1 mb-4"></div>
          <div class="pt-0">
            <div class="mb-4 text-center">
              <div class="text-2xl font-bold text-text">
                {length(@available_series)} series
              </div>
              <div class="text-xs text-subtext1">Available</div>
            </div>

            <%= if @selected_series != nil do %>
              <div class="flex justify-center mb-3">
                <button
                  phx-click="clear_filters"
                  class="text-xs text-subtext0 hover:text-text transition-colors px-2 py-1 hover:bg-surface0 rounded"
                >
                  Clear
                </button>
              </div>
            <% end %>

            <div class="space-y-2">
              <%= for series <- @available_series do %>
                <button
                  phx-click="toggle_series"
                  phx-value-series={series.slug}
                  class={[
                    "block w-full text-left px-2 py-1 text-sm transition-all duration-200 hover:bg-surface0 rounded",
                    if(series.slug == @selected_series,
                      do: "text-blue font-bold border-b-2 border-blue",
                      else: "text-subtext1 hover:text-text hover:border-b border-transparent"
                    )
                  ]}
                >
                  {series.title}
                </button>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>

      <%= if @current_user do %>
        <div class="p-6 flex-1">
          <h3 class="text-sm font-medium text-text mb-3">Admin</h3>
          <ul class="space-y-2">
            <li>
              <.link
                navigate="/posts"
                class="block text-subtext1 hover:text-text transition-colors py-2 px-3 rounded-lg hover:bg-surface0"
              >
                Manage Posts
              </.link>
            </li>
            <li>
              <.link
                href="/users/settings"
                class="block text-subtext1 hover:text-text transition-colors py-2 px-3 rounded-lg hover:bg-surface0"
              >
                Settings
              </.link>
            </li>
          </ul>
        </div>
      <% end %>

      <%= if @current_user do %>
        <div class="p-6 border-t border-surface1 mt-auto">
          <div class="text-subtext1 text-sm mb-2">{@current_user.email}</div>
          <.link
            href="/users/log_out"
            method="delete"
            class="text-subtext1 hover:text-text transition-colors text-sm"
          >
            Log out
          </.link>
        </div>
      <% end %>
    </nav>
    """
  end

  @doc """
  Renders a theme toggle button.

  ## Examples

      <.theme_toggle />
      
  """
  attr :id, :string, default: "theme-toggle"

  def theme_toggle(assigns) do
    ~H"""
    <button
      id={@id}
      type="button"
      class="p-2 rounded-lg border border-surface2 bg-surface0 hover:bg-surface1 transition-all duration-200 group"
      phx-hook="ThemeToggle"
      title="Toggle theme"
      aria-label="Toggle between light and dark theme"
    >
      <svg
        class="sun-icon w-5 h-5 text-maroon transition-all duration-200 group-hover:scale-110"
        fill="currentColor"
        viewBox="0 0 20 20"
        xmlns="http://www.w3.org/2000/svg"
      >
        <path
          fill-rule="evenodd"
          d="M10 2a1 1 0 011 1v1a1 1 0 11-2 0V3a1 1 0 011-1zm4 8a4 4 0 11-8 0 4 4 0 018 0zm-.464 4.95l.707.707a1 1 0 001.414-1.414l-.707-.707a1 1 0 00-1.414 1.414zm2.12-10.607a1 1 0 010 1.414l-.706.707a1 1 0 11-1.414-1.414l.707-.707a1 1 0 011.414 0zM17 11a1 1 0 100-2h-1a1 1 0 100 2h1zm-7 4a1 1 0 011 1v1a1 1 0 11-2 0v-1a1 1 0 011-1zM5.05 6.464A1 1 0 106.465 5.05l-.708-.707a1 1 0 00-1.414 1.414l.707.707zm1.414 8.486l-.707.707a1 1 0 01-1.414-1.414l.707-.707a1 1 0 011.414 1.414zM4 11a1 1 0 100-2H3a1 1 0 000 2h1z"
          clip-rule="evenodd"
        />
      </svg>

      <svg
        class="moon-icon w-5 h-5 text-lavender transition-all duration-200 group-hover:scale-110 hidden"
        fill="currentColor"
        viewBox="0 0 20 20"
        xmlns="http://www.w3.org/2000/svg"
      >
        <path d="M17.293 13.293A8 8 0 016.707 2.707a8.001 8.001 0 1010.586 10.586z" />
      </svg>
    </button>
    """
  end

  @doc """
  Renders a mobile drawer navigation that slides up from the bottom.

  ## Examples

      <.mobile_drawer id="mobile-nav" open={@drawer_open}>
        Navigation content here
      </.mobile_drawer>
      
  """
  attr :id, :string, required: true
  attr :open, :boolean, default: false
  slot :inner_block, required: true

  def mobile_drawer(assigns) do
    ~H"""
    <div
      id={"#{@id}-backdrop"}
      class={[
        "fixed inset-0 bg-base/80 backdrop-blur-sm z-40 transition-opacity duration-300 lg:hidden",
        if(@open, do: "opacity-100", else: "opacity-0 pointer-events-none")
      ]}
      phx-click="close_drawer"
      aria-hidden={if @open, do: "false", else: "true"}
    >
    </div>

    <div
      id={@id}
      class={[
        "fixed bottom-0 left-0 right-0 z-50 bg-mantle border-t border-surface1 rounded-t-xl shadow-2xl transform transition-transform duration-300 ease-out lg:hidden",
        if(@open, do: "translate-y-0", else: "translate-y-full")
      ]}
      phx-hook="MobileDrawer"
      role="dialog"
      aria-modal="true"
      aria-label="Navigation drawer"
      tabindex="-1"
      style="overscroll-behavior: contain; -webkit-overflow-scrolling: touch;"
    >
      <div class="flex justify-center p-2">
        <div class="w-12 h-1.5 bg-surface2 rounded-full"></div>
      </div>

      <div class="px-6 pb-6 max-h-[70vh] overflow-y-auto">
        {render_slot(@inner_block)}
      </div>
    </div>

    <div class={[
      "fixed bottom-6 left-1/2 transform -translate-x-1/2 z-40 lg:hidden",
      if(@open, do: "hidden", else: "block")
    ]}>
      <button
        phx-click="open_drawer"
        class="flex items-center gap-2 px-4 py-3 bg-blue hover:bg-blue/80 text-base rounded-full shadow-lg hover:shadow-xl transition-all duration-300 hover:scale-105"
        aria-label="Open navigation"
      >
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M4 6h16M4 12h16M4 18h16"
          />
        </svg>
        <span class="text-sm font-medium">Settings & Filters</span>
      </button>
    </div>
    """
  end

  @doc """
  Renders the posts content section (shared between desktop and mobile).
  """
  attr :posts, :list, required: true
  attr :selected_tags, :list, default: []
  attr :selected_series, :string, default: nil
  attr :search_query, :string, default: ""
  attr :has_more, :boolean, default: false
  attr :series_empty_state, :atom, default: nil

  def posts_content(assigns) do
    ~H"""
    <%= if @selected_tags != [] || @selected_series != nil || @search_query != "" do %>
      <div class="mb-6 p-4 bg-surface0/50 rounded-lg border border-surface1">
        <div class="flex items-center justify-between">
          <div class="text-sm text-subtext1">
            <%= cond do %>
              <% @selected_tags != [] && @selected_series != nil && @search_query != "" -> %>
                Showing posts tagged with <span class="text-blue">{Enum.join(@selected_tags, ", ")}</span>,
                in series <span class="text-blue">{@selected_series}</span>,
                matching "<span class="text-blue"><%= @search_query %></span>"
              <% @selected_tags != [] && @selected_series != nil -> %>
                Showing posts tagged with
                <span class="text-blue">{Enum.join(@selected_tags, ", ")}</span>
                in series <span class="text-blue">{@selected_series}</span>
              <% @selected_tags != [] && @search_query != "" -> %>
                Showing posts tagged with
                <span class="text-blue">{Enum.join(@selected_tags, ", ")}</span>
                matching "<span class="text-blue"><%= @search_query %></span>"
              <% @selected_series != nil && @search_query != "" -> %>
                Showing posts in series <span class="text-blue">{@selected_series}</span>
                matching "<span class="text-blue"><%= @search_query %></span>"
              <% @selected_tags != [] -> %>
                Showing posts tagged with
                <span class="text-blue">{Enum.join(@selected_tags, ", ")}</span>
              <% @selected_series != nil -> %>
                Showing posts in series <span class="text-blue">{@selected_series}</span>
              <% @search_query != "" -> %>
                Showing posts matching "<span class="text-blue"><%= @search_query %></span>"
            <% end %>
          </div>
          <button
            phx-click="clear_filters"
            class="text-xs text-subtext0 hover:text-text transition-colors"
          >
            Clear
          </button>
        </div>
      </div>
    <% end %>

    <%= for post <- @posts do %>
      <article>
        <.link
          navigate={"/blog/#{post.slug}"}
          class="block py-6 mx-2 hover:bg-surface1/20 transition-all duration-300 cursor-pointer rounded-2xl hover:shadow-[0_0_50px_10px_rgba(49,50,68,0.3)] relative"
        >
          <div class="space-y-4">
            <header class="px-4">
              <h2 class="text-xl font-semibold text-text mb-2">
                {post.title}
              </h2>
              <div class="flex items-center text-sm text-subtext1 space-x-4">
                <time datetime={post.published_at}>
                  {Calendar.strftime(post.published_at, "%B %d, %Y")}
                </time>
                <%= if Blog.Content.Post.tag_list(post) != [] do %>
                  <div class="flex items-center space-x-2">
                    <span>•</span>
                    <div class="flex flex-wrap gap-2">
                      <%= for tag <- Blog.Content.Post.tag_list(post) do %>
                        <span class="bg-surface1 text-subtext0 px-2 py-1 rounded text-xs">
                          {tag}
                        </span>
                      <% end %>
                    </div>
                  </div>
                <% end %>
              </div>
            </header>

            <%= if Map.get(post, :subtitle) do %>
              <div class="text-subtext1 text-sm px-4">
                {post.subtitle}
              </div>
            <% end %>

            <div class="relative">
              <div class="text-subtext1 overflow-hidden h-36 px-4">
                {Map.get(post, :rendered_preview) || Map.get(post, :preview_content) ||
                  Blog.Content.Post.preview_content(Map.get(post, :content, ""), 6)}
              </div>
            </div>
          </div>
          <div class="absolute bottom-0 left-0 right-0 h-48 bg-gradient-to-t from-mantle via-mantle/90 via-mantle/60 via-mantle/40 to-transparent pointer-events-none">
          </div>
        </.link>
      </article>
    <% end %>

    <%= if @has_more do %>
      <div class="mt-12 text-center py-8" id="loading-indicator">
        <div class="inline-flex items-center space-x-2 text-subtext1">
          <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-blue"></div>
          <span class="text-sm">Loading more posts...</span>
        </div>
      </div>
    <% end %>

    <%= if @posts == [] do %>
      <div class="text-center py-12">
        <%= if @selected_series != nil && (Map.get(assigns, :series_empty_state) == :upcoming_only || match?({:upcoming_only, _}, Map.get(assigns, :series_empty_state))) do %>
          <div class="text-6xl mb-4">🚀</div>
          <%= case Map.get(assigns, :series_empty_state) do %>
            <% {:upcoming_only, publish_date} when not is_nil(publish_date) -> %>
              <h2 class="text-xl font-semibold text-text mb-2">New Content Coming Soon!</h2>
              <p class="text-subtext1 mb-4">
                The first post in this series will be available on
                <span class="font-medium text-text">
                  {Calendar.strftime(publish_date, "%B %d, %Y at %I:%M %p")}
                </span>
                . Please check back then!
              </p>
            <% _ -> %>
              <h2 class="text-xl font-semibold text-text mb-2">Coming Soon!</h2>
              <p class="text-subtext1 mb-4">
                This series has exciting content in development. Please return later for new posts!
              </p>
          <% end %>
          <button
            phx-click="clear_filters"
            class="px-4 py-2 bg-blue hover:bg-blue/80 text-base rounded-lg font-medium transition-colors"
          >
            View All Posts
          </button>
        <% else %>
          <%= if @selected_tags != [] || @selected_series != nil || @search_query != "" do %>
            <div class="text-6xl mb-4">🔍</div>
            <h2 class="text-xl font-semibold text-text mb-2">No posts found</h2>
            <p class="text-subtext1 mb-4">No posts match your current filters.</p>
            <button
              phx-click="clear_filters"
              class="px-4 py-2 bg-blue hover:bg-blue/80 text-base rounded-lg font-medium transition-colors"
            >
              Clear Filters
            </button>
          <% else %>
            <div class="text-6xl mb-4">📝</div>
            <h2 class="text-xl font-semibold text-text mb-2">No posts yet</h2>
            <p class="text-subtext1">Check back later for new content.</p>
          <% end %>
        <% end %>
      </div>
    <% end %>
    """
  end

  @doc """
  Renders mobile-optimized navigation content for the drawer.
  """
  attr :current_user, :any, default: nil
  attr :top_tags, :list, default: []
  attr :available_tags, :list, default: []
  attr :selected_tags, :list, default: []
  attr :available_series, :list, default: []
  attr :selected_series, :string, default: nil
  attr :search_query, :string, default: ""
  attr :search_suggestions, :list, default: []

  def mobile_content_nav(assigns) do
    ~H"""
    <div class="relative mb-6">
      <div class="rounded-lg focus-within:border-blue transition-colors p-3">
        <form phx-submit="search" class="relative">
          <input
            type="text"
            name="query"
            value={@search_query}
            placeholder="Search posts and/or filter by tags..."
            class="w-full bg-transparent text-text placeholder-subtext0 focus:outline-none text-sm"
            phx-keyup="search_input"
            phx-debounce="300"
            autocomplete="off"
          />
        </form>

        <%= if @search_query != "" && @search_suggestions != [] do %>
          <div class="mt-2 space-y-1">
            <%= for suggestion <- @search_suggestions do %>
              <button
                type="button"
                phx-click="add_tag_from_search"
                phx-value-tag={suggestion}
                class="w-full text-left px-3 py-2 text-sm text-text hover:bg-surface1 rounded transition-colors flex items-center gap-2"
              >
                <span class="w-4 h-4 bg-blue/20 rounded-full flex items-center justify-center">
                  <span class="w-2 h-2 bg-blue rounded-full"></span>
                </span>
                {suggestion}
              </button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <div>
      <div class="mb-4 text-center">
        <div class="text-2xl font-bold text-text">
          {length(@available_tags)} tags
        </div>
        <div class="text-xs text-subtext1">Available</div>
      </div>

      <div class="flex items-center justify-between mb-3">
        <h3 class="text-sm font-medium text-text">Popular Tags</h3>
        <%= if @selected_tags != [] do %>
          <button
            phx-click="clear_filters"
            class="text-xs text-subtext0 hover:text-text transition-colors px-2 py-1 hover:bg-surface0 rounded"
          >
            Clear
          </button>
        <% end %>
      </div>

      <div class="flex flex-wrap gap-2 mb-4">
        <%= for tag <- @top_tags do %>
          <button
            phx-click="toggle_tag"
            phx-value-tag={tag}
            class={[
              "px-3 py-2 text-sm rounded-full border transition-all duration-200 hover:scale-105",
              if(tag in @selected_tags,
                do: "border-blue text-white bg-blue",
                else: "border-surface2 text-subtext1 hover:border-blue/50 hover:text-blue"
              )
            ]}
          >
            {tag}
          </button>
        <% end %>
      </div>

      <%= if Enum.any?(@selected_tags, fn tag -> tag not in @top_tags end) do %>
        <div class="mb-4">
          <h4 class="text-xs font-medium text-subtext1 mb-2">Additional Tags</h4>
          <div class="flex flex-wrap gap-2">
            <%= for tag <- @selected_tags, tag not in @top_tags do %>
              <button
                phx-click="toggle_tag"
                phx-value-tag={tag}
                class="px-3 py-2 text-sm rounded-full border border-blue text-white bg-blue transition-all duration-200 hover:scale-105"
              >
                {tag}
              </button>
            <% end %>
          </div>
        </div>
      <% end %>

      <%= if @available_series != [] do %>
        <div class="border-t border-surface1 pt-4">
          <div class="mb-4 text-center">
            <div class="text-2xl font-bold text-text">
              {length(@available_series)} series
            </div>
            <div class="text-xs text-subtext1">Available</div>
          </div>

          <%= if @selected_series != nil do %>
            <div class="flex justify-center mb-3">
              <button
                phx-click="clear_filters"
                class="text-xs text-subtext0 hover:text-text transition-colors px-2 py-1 hover:bg-surface0 rounded"
              >
                Clear
              </button>
            </div>
          <% end %>

          <div class="space-y-2">
            <%= for series <- @available_series do %>
              <button
                phx-click="toggle_series"
                phx-value-series={series.slug}
                class={[
                  "block w-full text-left px-2 py-1 text-sm transition-all duration-200 hover:bg-surface0 rounded",
                  if(series.slug == @selected_series,
                    do: "text-blue font-bold border-b-2 border-blue",
                    else: "text-subtext1 hover:text-text hover:border-b border-transparent"
                  )
                ]}
              >
                {series.title}
              </button>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>

    <%= if @current_user do %>
      <div class="pt-6 border-t border-surface1">
        <h3 class="text-sm font-medium text-text mb-3">Admin</h3>
        <ul class="space-y-2">
          <li>
            <.link
              navigate="/posts"
              class="block text-subtext1 hover:text-text transition-colors py-2 px-3 rounded-lg hover:bg-surface0"
            >
              Manage Posts
            </.link>
          </li>
          <li>
            <.link
              href="/users/settings"
              class="block text-subtext1 hover:text-text transition-colors py-2 px-3 rounded-lg hover:bg-surface0"
            >
              Settings
            </.link>
          </li>
          <li class="pt-2 border-t border-surface1/50">
            <div class="text-subtext1 text-sm mb-2">{@current_user.email}</div>
            <.link
              href="/users/log_out"
              method="delete"
              class="text-subtext1 hover:text-text transition-colors text-sm"
            >
              Log out
            </.link>
          </li>
        </ul>
      </div>
    <% end %>
    """
  end
end
