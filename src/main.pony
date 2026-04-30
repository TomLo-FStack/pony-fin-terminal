use "collections"
use "files"
use "format"

use @system[I32](cmd: Pointer[U8] tag)

class val Quote
  let symbol: String
  let date: String
  let time: String
  let open: String
  let high: String
  let low: String
  let close: String
  let volume: String

  new val create(
    symbol': String,
    date': String,
    time': String,
    open': String,
    high': String,
    low': String,
    close': String,
    volume': String)
  =>
    symbol = symbol'
    date = date'
    time = time'
    open = open'
    high = high'
    low = low'
    close = close'
    volume = volume'

primitive Text
  fun clean(value: String box): String val =>
    recover val
      let out = value.clone()
      out.strip(" \t\r\n")
      out
    end

  fun lower_clean(value: String box): String val =>
    recover val
      let out = value.clone()
      out.strip(" \t\r\n")
      out.lower_in_place()
      out
    end

  fun safe_symbol(raw: String box): (String val | None) =>
    let out = recover String end
    for b in raw.values() do
      if ((b >= 'a') and (b <= 'z')) or
        ((b >= 'A') and (b <= 'Z')) or
        ((b >= '0') and (b <= '9')) or
        (b == '.') or (b == '_') or (b == '-')
      then
        out.push(b)
      end
    end

    out.lower_in_place()
    out.strip(" ._-")

    if out.size() == 0 then
      None
    else
      let has_exchange = try out.find(".")? >= 0 else false end
      if not has_exchange then out.append(".us") end
      recover val out end
    end

primitive CsvQuote
  fun parse(data: String): Quote ? =>
    let rows = data.split_by("\n")
    if rows.size() < 2 then error end

    let line = Text.clean(rows(1)?)
    let cols = line.split_by(",")
    if cols.size() < 8 then error end

    Quote(
      Text.clean(cols(0)?),
      Text.clean(cols(1)?),
      Text.clean(cols(2)?),
      Text.clean(cols(3)?),
      Text.clean(cols(4)?),
      Text.clean(cols(5)?),
      Text.clean(cols(6)?),
      Text.clean(cols(7)?))

class QuoteService
  let _cache_dir: FilePath

  new create(env: Env) =>
    let caps = recover val FileCaps.>all() end
    _cache_dir = FilePath(FileAuth(env.root), ".pony-fin-cache", caps)
    _cache_dir.mkdir()

  fun ref fetch(raw: String): (Quote | String) =>
    match Text.safe_symbol(raw)
    | let symbol: String val =>
      try
        let out_path = _cache_dir.join(symbol + ".csv")?
        let url: String val = recover val
          "https://stooq.com/q/l/?s=" + symbol + "&f=sd2t2ohlcv&h&e=csv"
        end
        let cmd: String val = recover val
          "curl -fsSL -A \"pony-fin-terminal/0.1\" \"" + url +
          "\" -o \"" + out_path.path + "\""
        end

        let rc = @system(cmd.cstring())
        if rc != 0 then
          return "fetch failed for " + symbol + " (curl exit " + rc.string() + ")"
        end

        let csv = _read_text(out_path)?
        let quote = CsvQuote.parse(csv)?
        if quote.date == "N/D" then
          "no quote returned for " + symbol
        else
          quote
        end
      else
        "could not parse quote for " + symbol
      end
    | None =>
      "invalid symbol: " + raw
    end

  fun ref _read_text(path: FilePath): String ? =>
    match OpenFile(path)
    | let file: File =>
      let data = file.read_string(file.size())
      file.dispose()
      consume data
    else
      error
    end

actor Main
  new create(env: Env) =>
    try
      let command = Text.lower_clean(env.args(1)?)
      match command
      | "help" => _help(env)
      | "--help" => _help(env)
      | "-h" => _help(env)
      | "source" => _source(env)
      | "quote" => _quote(env, _symbols_from_args(env, 2))
      | "watch" => _quote(env, _watchlist(env))
      else
        _quote(env, _symbols_from_args(env, 1))
      end
    else
      _quote(env, _watchlist(env))
    end

  fun _quote(env: Env, symbols: Array[String] box) =>
    if symbols.size() == 0 then
      env.err.print("No symbols. Try: pony-fin-terminal quote AAPL MSFT SPY")
      env.exitcode(2)
      return
    end

    let service = QuoteService(env)
    let quotes = Array[Quote]
    let errors = Array[String]

    for symbol in symbols.values() do
      match service.fetch(symbol)
      | let quote: Quote => quotes.push(quote)
      | let err: String => errors.push(err)
      end
    end

    _print_table(env, quotes)

    for err in errors.values() do
      env.err.print(err)
    end

    if (quotes.size() == 0) and (errors.size() > 0) then
      env.exitcode(1)
    end

  fun _print_table(env: Env, quotes: Array[Quote] box) =>
    if quotes.size() == 0 then return end

    env.out.print(
      Format("SYMBOL" where width = 12) +
      Format("DATE" where width = 12) +
      Format("TIME" where width = 11) +
      Format("OPEN" where width = 11, align = AlignRight) +
      Format("HIGH" where width = 11, align = AlignRight) +
      Format("LOW" where width = 11, align = AlignRight) +
      Format("CLOSE" where width = 11, align = AlignRight) +
      Format("CHG" where width = 11, align = AlignRight) +
      Format("CHG%" where width = 10, align = AlignRight) +
      Format("VOLUME" where width = 14, align = AlignRight))

    for q in quotes.values() do
      (let chg, let pct) = _change(q)
      env.out.print(
        Format(q.symbol where width = 12) +
        Format(q.date where width = 12) +
        Format(q.time where width = 11) +
        Format(q.open where width = 11, align = AlignRight) +
        Format(q.high where width = 11, align = AlignRight) +
        Format(q.low where width = 11, align = AlignRight) +
        Format(q.close where width = 11, align = AlignRight) +
        Format(chg where width = 11, align = AlignRight) +
        Format(pct where width = 10, align = AlignRight) +
        Format(q.volume where width = 14, align = AlignRight))
    end

  fun _change(q: Quote): (String, String) =>
    try
      let o = q.open.f64()?
      let c = q.close.f64()?
      if o == 0 then error end
      let diff = c - o
      let pct = (diff / o) * 100
      (Format.float[F64](diff where fmt = FormatFix, prec = 2),
        Format.float[F64](pct where fmt = FormatFix, prec = 2) + "%")
    else
      ("N/D", "N/D")
    end

  fun _symbols_from_args(env: Env, start: USize): Array[String] iso^ =>
    let out = recover Array[String] end
    var i = start
    while i < env.args.size() do
      try
        let value = Text.clean(env.args(i)?)
        if value.size() > 0 then out.push(value) end
      end
      i = i + 1
    end
    consume out

  fun _watchlist(env: Env): Array[String] iso^ =>
    let out = recover Array[String] end
    let caps = recover val FileCaps.>all() end
    let path = FilePath(FileAuth(env.root), "config/watchlist.txt", caps)

    try
      with file = OpenFile(path) as File do
        for line' in file.lines() do
          let line = Text.clean(consume line')
          if (line.size() > 0) and (not _is_comment(line)) then
            out.push(line)
          end
        end
      end
    end

    if out.size() == 0 then
      out.push("AAPL")
      out.push("MSFT")
      out.push("SPY")
    end

    consume out

  fun _is_comment(line: String box): Bool =>
    try line(0)? == '#' else false end

  fun _help(env: Env) =>
    env.out.print("Pony Finance Terminal")
    env.out.print("")
    env.out.print("Usage:")
    env.out.print("  pony-fin-terminal watch")
    env.out.print("  pony-fin-terminal quote AAPL MSFT TSLA")
    env.out.print("  pony-fin-terminal AAPL")
    env.out.print("  pony-fin-terminal source")
    env.out.print("")
    env.out.print("Symbols without an exchange suffix default to Stooq .us.")

  fun _source(env: Env) =>
    env.out.print("Source: Stooq public quote CSV endpoint")
    env.out.print("Endpoint shape: https://stooq.com/q/l/?s=aapl.us&f=sd2t2ohlcv&h&e=csv")
    env.out.print("Fields: symbol, date, time, open, high, low, close, volume")
    env.out.print("This is informational market data, not investment advice.")
