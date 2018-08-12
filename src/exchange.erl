-module(exchange).
-behaviour(gen_server).

%% API.
-export([start_link/0, add_client/1, trade_stock/3, get_stocks/0, get_clients/0]).

%% gen_server.
-export([init/1]).
-export([handle_call/3]).
-export([handle_cast/2]).
-export([handle_info/2]).
-export([terminate/2]).
-export([code_change/3]).

-record(state, {
      stocks = [],
      clients = [],
      trades = []
}).

%% API.

-spec start_link() -> {ok, pid()}.
start_link() ->
	gen_server:start_link({global, ?MODULE}, ?MODULE, [], []).

add_client(Name)->
  gen_server:call({global, ?MODULE}, {register_client, Name}).

trade_stock(StockName, Qty, Price)->
  gen_server:call({global, ?MODULE}, {trade, StockName, Qty, Price}).

get_stocks()->
  gen_server:call({global, ?MODULE}, get_stocks).

get_clients()->
  gen_server:call({global, ?MODULE}, get_clients).

get_trades()->
  gen_server:call({global, ?MODULE}, get_trades).

%% internal
trade_stock({ExchName, Qty, _Price}, {_, TradeQty, NewPrice})->
  {ExchName, Qty - TradeQty, NewPrice}.

lookup_pid([{Name, ClientPid}| _Rest], Pid) when ClientPid == Pid ->
  {Name, Pid};

lookup_pid([First | Rest], Pid)->
  io:format(user, "First is ~w ~w~n ", [First, Pid]),
  lookup_pid(Rest, Pid);

lookup_pid([], Pid) ->
  {unknown, Pid}.


%% gen_server.

init([]) ->
	{ok, #state{}}.

handle_call(get_clients, _From, State)->
  {reply, State#state.clients, State};

handle_call(get_stocks, _From, State)->
  {reply, State#state.stocks, State};

handle_call(get_trades, _From, State)->
  {reply, State#state.trades, State};

handle_call({trade, Name, Qty, Price}, {Pid, _Tag}, State)->
  S = case lists:keyfind(Name, 1, State#state.stocks) of
        false -> State#state{stocks= State#state.stocks ++ [{Name, Qty, Price}]};
        Found -> State#state{stocks= lists:keyreplace(Name, 1, State#state.stocks, trade_stock(Found, {Name, Qty, Price}))}
      end,
  {reply, ok, S#state{trades = S#state.trades ++ [{Name, Qty, Price, lookup_pid(S#state.clients, Pid)}]  }};

handle_call({register_client, Name}, {Pid, _Tag}, State)->
  S = case lists:keyfind(Name, 1, State#state.clients) of
        false -> State#state{clients = State#state.clients ++ [{Name, Pid}]};
        _Else -> State#state{clients = lists:keyreplace(Name, 1, State#state.clients, {Name, Pid})}
      end,
  {reply, ok, S};

handle_call(_Request, _From, State) ->
	{reply, 1, State}.

handle_cast(_Msg, State) ->
	{noreply, State}.

handle_info(_Info, State) ->
	{noreply, State}.

terminate(_Reason, _State) ->
	ok.

code_change(_OldVsn, State, _Extra) ->
	{ok, State}.


-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").

lifecycle_exchange_test()->
  {ok, _}  = start_link(),
  [] = get_stocks(),
  [] = get_clients(),
  add_client(trader1),
  [{trader1, _}] = get_clients(),
  ok = trade_stock(apple, 10, 20.45),
  [{apple, 10, 20.45}] = get_stocks(),
  [{apple, 10, 20.45, {trader1, _}}] = get_trades(),
  1 = gen_server:call({global, ?MODULE}, ok).

-endif.

