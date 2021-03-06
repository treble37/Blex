defmodule Blex.SettingsCache do
  use GenServer
  @moduledoc """
  This is an abstraction that handles the storing, updating and deleting of the settings cache.

  All the blogs settings are stored via the :dets module, under the file name `:settings_cache`. Since
  they will be accessed frequently, using the dets for storage ensures the lookup will be fast.

  When the genserver exits, the ets table is transferred to the backup dets table.

  The available settings are:

  * :initial_setup -> boolean
  * :comment_platform -> string
  * :blog_name -> string
  * :blog_tagline -> string
  * :header_title -> string
  * :logo -> string
  * :favicon -> string
  * :header_content -> string
  * :footer_content -> string

  This means that the settings will be persisted on a server restart.

  The api is very simple and exposes two methods:

  `SettingsCache.fetch(key)`
  `SettingsCache.update(key, value)`

  For example:

  ```elixir
  iex(1)> SettingsCache.fetch(:blog_name)
  {:ok, "Harry's Blog"}


  iex(2)> SettingsCache.update(:blog_name, "Glen's Blog")
  {:ok, "Glen's Blog}
  ```
  """

  # -------- PUBLIC
  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Updates the given key with the passed in value.
  """
  def update_setting(key, val) do
    GenServer.call(__MODULE__, {:update, key, val})
  end

  @doc """
  Fetches the value for the given key. If the key has no associated value
  then `{:error, "Setting not found"}` is returned
  """
  def get_setting(key) do
    GenServer.call(__MODULE__, {:fetch, key})
  end

  # -------- GENSERVER IMPLEMENTATION
  def init(_) do
    Process.flag(:trap_exit, :true)
    :ets.new(:settings_cache, [:named_table])
    load_existing_settings
    load_defaults
    {:ok, []}
  end

  def handle_call({:fetch, key}, _from, state) do
    val = 
      case :ets.lookup(:settings_cache, key) do
        [] -> 
          {:reply, {:error, "Setting not found"}, state}
        [{_key, val} | _rest] -> 
          {:reply, {:ok, val}, state}
      end
  end

  def handle_call({:update, key, val}, _from, state) do
    :ets.insert(:settings_cache, {key, val})
    :dets.insert(:settings_cache_disk, {key, val})
    {:reply, {:ok, val}, state}
  end

  # Used for tests
  def handle_call({:clear}, _from, state) do
    :settings_cache
    |> :ets.tab2list
    |> Enum.each(fn({key, _}) -> :ets.delete(:settings_cache, key) end)
    {:reply, {:ok}, state}
  end

  def terminate(_reason, state) do
    :ets.to_dets(:settings_cache, :settings_cache_disk)
    :dets.close(:settings_cache_disk)
    :ok
  end

  # ------ PRIVATE
  defp load_existing_settings do
    :settings_cache_disk
    |> :dets.open_file([type: :set]) 
    |> elem(1)
    |> :dets.to_ets(:settings_cache)
  end

  defp load_defaults do
    [
      {:initial_setup, false},
      {:comment_platform, :blex},
      {:blog_name, "Blog Name"},
      {:blog_tagline, "Your Blog tagline"},
      {:header_title, "Blog title"},
      {:logo, "http://logo_url"},
      {:favicon, "http://favicon_url"},
      {:header_content, "custom code inserted before <body>"},
      {:footer_content, "custom code inserted after <body>"}
    ]
    |> Enum.each(fn({k,v}) ->
      case :ets.lookup(:settings_cache, k) do
        [] ->
          :ets.insert(:settings_cache, {k,v})
        _ ->
          nil
      end
    end)
  end


end
