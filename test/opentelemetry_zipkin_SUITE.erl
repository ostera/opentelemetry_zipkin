-module(opentelemetry_zipkin_SUITE).

-compile(export_all).

-include_lib("stdlib/include/assert.hrl").
-include_lib("opentelemetry_api/include/opentelemetry.hrl").
-include_lib("opentelemetry/include/ot_span.hrl").

all() ->
    [verify_export].

%% insert a couple spans and export to locally running zipkin
verify_export(_Config) ->
    Address = case os:getenv("GITHUB_ACTION") of
                  false ->
                      "http://localhost:9411/api/v2/spans";
                  _ ->
                      "http://zipkin:9411/api/v2/spans"
              end,
    Resource = ot_resource:create([{"service.name",
                                    "my-test-service"}]),
    {ok, State} = opentelemetry_zipkin:init(#{address => Address,
                                             local_endpoint => #{service_name => my_service,
                                                                 ip4 => {1,2,3,4},
                                                                 port => 8000}}),
    Tid = ets:new(span_tab, [{keypos, #span.span_id}]),

    ?assertMatch(ok, opentelemetry_zipkin:export(Tid, Resource, State)),

    TraceId = opentelemetry:generate_trace_id(),
    SpanId = opentelemetry:generate_span_id(),

    ParentSpan =
        #span{name = <<"span-1">>,
              trace_id = TraceId,
              span_id = SpanId,
              kind = ?SPAN_KIND_CLIENT,
              start_time = wts:timestamp(),
              end_time = wts:timestamp(),
              events = [#event{time=wts:timestamp(),
                               name = <<"event-1">>,
                               attributes = [{<<"attr-1">>, <<"value-1">>}]},
                        #event{time=wts:timestamp(),
                               name = <<"event-2">>,
                               attributes = [{<<"attr-3">>, <<"value-3">>}]}],
              attributes = [{<<"attr-2">>, <<"value-2">>}]},
    true = ets:insert(Tid, ParentSpan),

    ChildSpan = #span{name = <<"span-2">>,
                      trace_id = TraceId,
                      span_id = opentelemetry:generate_span_id(),
                      parent_span_id = SpanId,
                      kind = ?SPAN_KIND_SERVER,
                      start_time = wts:timestamp(),
                      end_time = wts:timestamp(),
                      events = [#event{time=wts:timestamp(),
                                       name = <<"event-1">>,
                                       attributes = [{<<"attr-1">>, <<"value-1">>}]},
                                #event{time=wts:timestamp(),
                                       name = <<"event-2">>,
                                       attributes = [{<<"attr-3">>, <<"value-3">>}]}],
                      attributes = [{<<"attr-2">>, <<"value-2">>}]},
    true = ets:insert(Tid, ChildSpan),

    ?assertMatch(ok, opentelemetry_zipkin:export(Tid, Resource, State)),
    ok.
