defmodule NimbleParsecTest do
  use ExUnit.Case, async: true

  import NimbleParsec
  doctest NimbleParsec

  describe "ascii_char/2 combinator without newlines" do
    defparsec :only_ascii, ascii_char([?0..?9]) |> ascii_char([])
    defparsec :multi_ascii, ascii_char([?0..?9, ?z..?a])
    defparsec :multi_ascii_with_not, ascii_char([?0..?9, ?z..?a, not: ?c])
    defparsec :multi_ascii_with_multi_not, ascii_char([?0..?9, ?z..?a, not: ?c, not: ?d..?e])
    defparsec :ascii_newline, ascii_char([?0..?9, ?\n]) |> ascii_char([?a..?z, ?\n])

    @error "expected byte in the range ?0..?9, followed by byte"

    test "returns ok/error on composition" do
      assert only_ascii("1a") == {:ok, [?1, ?a], "", 1, 3}
      assert only_ascii("11") == {:ok, [?1, ?1], "", 1, 3}
      assert only_ascii("a1") == {:error, @error, "a1", 1, 1}
    end

    @error "expected byte in the range ?0..?9 or in the range ?z..?a"

    test "returns ok/error on multiple ranges" do
      assert multi_ascii("1a") == {:ok, [?1], "a", 1, 2}
      assert multi_ascii("a1") == {:ok, [?a], "1", 1, 2}
      assert multi_ascii("++") == {:error, @error, "++", 1, 1}
    end

    @error "expected byte in the range ?0..?9 or in the range ?z..?a, and not equal to ?c"

    test "returns ok/error on multiple ranges with not" do
      assert multi_ascii_with_not("1a") == {:ok, [?1], "a", 1, 2}
      assert multi_ascii_with_not("a1") == {:ok, [?a], "1", 1, 2}
      assert multi_ascii_with_not("++") == {:error, @error, "++", 1, 1}
      assert multi_ascii_with_not("cc") == {:error, @error, "cc", 1, 1}
    end

    @error "expected byte in the range ?0..?9 or in the range ?z..?a, and not equal to ?c, and not in the range ?d..?e"

    test "returns ok/error on multiple ranges with multiple not" do
      assert multi_ascii_with_multi_not("1a") == {:ok, [?1], "a", 1, 2}
      assert multi_ascii_with_multi_not("a1") == {:ok, [?a], "1", 1, 2}
      assert multi_ascii_with_multi_not("++") == {:error, @error, "++", 1, 1}
      assert multi_ascii_with_multi_not("cc") == {:error, @error, "cc", 1, 1}
      assert multi_ascii_with_multi_not("de") == {:error, @error, "de", 1, 1}
    end

    test "returns ok/error even with newlines" do
      assert ascii_newline("1a\n") == {:ok, [?1, ?a], "\n", 1, 3}
      assert ascii_newline("1\na") == {:ok, [?1, ?\n], "a", 2, 1}
      assert ascii_newline("\nao") == {:ok, [?\n, ?a], "o", 2, 2}
    end

    test "is bound" do
      assert bound?(ascii_char([?0..?9]))
      assert bound?(ascii_char(not: ?\n))
    end
  end

  describe "utf8_char/2 combinator without newlines" do
    defparsec :only_utf8, utf8_char([?0..?9]) |> utf8_char([])
    defparsec :utf8_newline, utf8_char([]) |> utf8_char([?a..?z, ?\n])

    @error "expected utf8 codepoint in the range ?0..?9, followed by utf8 codepoint"

    test "returns ok/error on composition" do
      assert only_utf8("1a") == {:ok, [?1, ?a], "", 1, 3}
      assert only_utf8("11") == {:ok, [?1, ?1], "", 1, 3}
      assert only_utf8("1é") == {:ok, [?1, ?é], "", 1, 3}
      assert only_utf8("a1") == {:error, @error, "a1", 1, 1}
    end

    test "returns ok/error even with newlines" do
      assert utf8_newline("1a\n") == {:ok, [?1, ?a], "\n", 1, 3}
      assert utf8_newline("1\na") == {:ok, [?1, ?\n], "a", 2, 1}
      assert utf8_newline("éa\n") == {:ok, [?é, ?a], "\n", 1, 3}
      assert utf8_newline("é\na") == {:ok, [?é, ?\n], "a", 2, 1}
      assert utf8_newline("\nao") == {:ok, [?\n, ?a], "o", 2, 2}
    end

    test "is bound" do
      assert bound?(utf8_char([?0..?9]))
      assert bound?(utf8_char(not: ?\n))
    end
  end

  describe "integer/3 combinator with exact length" do
    defparsec :only_integer, integer(2)
    defparsec :prefixed_integer, literal("T") |> integer(2)

    @error "expected byte in the range ?0..?9, followed by byte in the range ?0..?9"

    test "returns ok/error by itself" do
      assert only_integer("12") == {:ok, [12], "", 1, 3}
      assert only_integer("123") == {:ok, [12], "3", 1, 3}
      assert only_integer("1a3") == {:error, @error, "1a3", 1, 1}
    end

    @error "expected literal \"T\", followed by byte in the range ?0..?9, followed by byte in the range ?0..?9"

    test "returns ok/error with previous document" do
      assert prefixed_integer("T12") == {:ok, ["T", 12], "", 1, 4}
      assert prefixed_integer("T123") == {:ok, ["T", 12], "3", 1, 4}
      assert prefixed_integer("T1a3") == {:error, @error, "T1a3", 1, 1}
    end

    test "is bound" do
      assert bound?(integer(2))
      assert bound?(literal("T") |> integer(2))
      assert bound?(literal("T") |> integer(2) |> literal("E"))
    end
  end

  describe "literal/2 combinator" do
    defparsec :only_literal, literal("TO")
    defparsec :only_literal_with_newline, literal("T\nO")

    test "returns ok/error" do
      assert only_literal("TO") == {:ok, ["TO"], "", 1, 3}
      assert only_literal("TOC") == {:ok, ["TO"], "C", 1, 3}
      assert only_literal("AO") == {:error, "expected literal \"TO\"", "AO", 1, 1}
    end

    test "properly counts newlines" do
      assert only_literal_with_newline("T\nO") == {:ok, ["T\nO"], "", 2, 2}
      assert only_literal_with_newline("T\nOC") == {:ok, ["T\nO"], "C", 2, 2}

      assert only_literal_with_newline("A\nO") ==
               {:error, "expected literal \"T\\nO\"", "A\nO", 1, 1}
    end

    test "is bound" do
      assert bound?(literal("T"))
    end
  end

  describe "ignore/2 combinator at compile time" do
    defparsec :compile_ignore, ignore(literal("TO"))
    defparsec :compile_ignore_with_newline, ignore(literal("T\nO"))

    test "returns ok/error" do
      assert compile_ignore("TO") == {:ok, [], "", 1, 3}
      assert compile_ignore("TOC") == {:ok, [], "C", 1, 3}
      assert compile_ignore("AO") == {:error, "expected literal \"TO\"", "AO", 1, 1}
    end

    test "properly counts newlines" do
      assert compile_ignore_with_newline("T\nO") == {:ok, [], "", 2, 2}
      assert compile_ignore_with_newline("T\nOC") == {:ok, [], "C", 2, 2}

      assert compile_ignore_with_newline("A\nO") ==
               {:error, "expected literal \"T\\nO\"", "A\nO", 1, 1}
    end

    test "is bound" do
      assert bound?(ignore(literal("T")))
    end
  end

  describe "ignore/2 combinator at runtime" do
    defparsec :runtime_ignore,
              ascii_char([?a..?z])
              |> ascii_char([?a..?z])
              |> ascii_char([?a..?z])
              |> map({:to_string, []})
              |> ignore()

    test "returns ok/error" do
      assert runtime_ignore("abc") == {:ok, [], "", 1, 4}

      error =
        "expected byte in the range ?a..?z, followed by byte in the range ?a..?z, followed by byte in the range ?a..?z"

      assert runtime_ignore("1bc") == {:error, error, "1bc", 1, 1}
    end

    test "is not bound" do
      assert not_bound?(ascii_char([?a..?z]) |> map({:to_string, []}) |> ignore())
    end
  end

  describe "replace/3 combinator at compile time" do
    defparsec :compile_replace, replace(literal("TO"), "OTHER")
    defparsec :compile_replace_with_newline, replace(literal("T\nO"), "OTHER")
    defparsec :compile_replace_empty, replace(empty(), "OTHER")

    test "returns ok/error" do
      assert compile_replace("TO") == {:ok, ["OTHER"], "", 1, 3}
      assert compile_replace("TOC") == {:ok, ["OTHER"], "C", 1, 3}
      assert compile_replace("AO") == {:error, "expected literal \"TO\"", "AO", 1, 1}
    end

    test "can replace empty" do
      assert compile_replace_empty("TO") == {:ok, ["OTHER"], "TO", 1, 1}
    end

    test "properly counts newlines" do
      assert compile_replace_with_newline("T\nO") == {:ok, ["OTHER"], "", 2, 2}
      assert compile_replace_with_newline("T\nOC") == {:ok, ["OTHER"], "C", 2, 2}

      assert compile_replace_with_newline("A\nO") ==
               {:error, "expected literal \"T\\nO\"", "A\nO", 1, 1}
    end

    test "is bound" do
      assert bound?(replace(literal("T"), "OTHER"))
      assert bound?(replace(empty(), "OTHER"))
    end
  end

  describe "replace/2 combinator at runtime" do
    defparsec :runtime_replace,
              ascii_char([?a..?z])
              |> ascii_char([?a..?z])
              |> ascii_char([?a..?z])
              |> map({:to_string, []})
              |> replace("OTHER")

    test "returns ok/error" do
      assert runtime_replace("abc") == {:ok, ["OTHER"], "", 1, 4}

      error =
        "expected byte in the range ?a..?z, followed by byte in the range ?a..?z, followed by byte in the range ?a..?z"

      assert runtime_replace("1bc") == {:error, error, "1bc", 1, 1}
    end

    test "is not bound" do
      assert not_bound?(ascii_char([?a..?z]) |> map({:to_string, []}) |> replace("OTHER"))
    end
  end

  describe "label/3 combinator at compile time" do
    defparsec :compile_label, label(literal("TO"), "label")
    defparsec :compile_label_with_newline, label(literal("T\nO"), "label")

    test "returns ok/error" do
      assert compile_label("TO") == {:ok, ["TO"], "", 1, 3}
      assert compile_label("TOC") == {:ok, ["TO"], "C", 1, 3}
      assert compile_label("AO") == {:error, "expected label", "AO", 1, 1}
    end

    test "properly counts newlines" do
      assert compile_label_with_newline("T\nO") == {:ok, ["T\nO"], "", 2, 2}
      assert compile_label_with_newline("T\nOC") == {:ok, ["T\nO"], "C", 2, 2}
      assert compile_label_with_newline("A\nO") == {:error, "expected label", "A\nO", 1, 1}
    end

    test "is bound" do
      assert bound?(label(literal("T"), "label"))
    end
  end

  describe "label/3 combinator at runtime" do
    defparsec :runtime_label,
              label(ascii_char([?a..?z]), "first label")
              |> label(ascii_char([?a..?z]) |> map({:to_string, []}), "second label")
              |> ascii_char([?a..?z])
              |> map({:to_string, []})
              |> label("third label")

    test "returns ok/error" do
      assert runtime_label("abc") == {:ok, ["97", "98", "99"], "", 1, 4}

      error = "expected third label"
      assert runtime_label("1bc") == {:error, error, "1bc", 1, 1}

      error = "expected second label while processing third label"
      assert runtime_label("a1c") == {:error, error, "1c", 1, 2}

      error = "expected third label"
      assert runtime_label("ab1") == {:error, error, "1", 1, 3}
    end

    test "is not bound" do
      assert not_bound?(ascii_char([?a..?z]) |> map({:to_string, []}) |> label("label"))
    end
  end

  describe "remote traverse/3 combinator" do
    @three_ascii_letters ascii_char([?a..?z])
                         |> ascii_char([?a..?z])
                         |> ascii_char([?a..?z])

    defparsec :remote_traverse,
              literal("T")
              |> integer(2)
              |> traverse(@three_ascii_letters, {__MODULE__, :public_join_and_wrap, ["-"]})
              |> integer(2)

    test "returns ok/error" do
      assert remote_traverse("T12abc34") == {:ok, ["T", 12, "99-98-97", 34], "", 1, 9}

      error =
        "expected literal \"T\", followed by byte in the range ?0..?9, followed by byte in the range ?0..?9"

      assert remote_traverse("Tabc34") == {:error, error, "Tabc34", 1, 1}

      error = "expected byte in the range ?0..?9, followed by byte in the range ?0..?9"
      assert remote_traverse("T12abcdf") == {:error, error, "df", 1, 7}

      error =
        "expected byte in the range ?a..?z, followed by byte in the range ?a..?z, followed by byte in the range ?a..?z"

      assert remote_traverse("T12ab34") == {:error, error, "ab34", 1, 4}
    end

    test "is not bound" do
      assert not_bound?(
               traverse(@three_ascii_letters, {__MODULE__, :public_join_and_wrap, ["-"]})
             )
    end

    def public_join_and_wrap(args, joiner) do
      args |> Enum.join(joiner) |> List.wrap()
    end
  end

  describe "local traverse/3 combinator" do
    @three_ascii_letters ascii_char([?a..?z])
                         |> ascii_char([?a..?z])
                         |> ascii_char([?a..?z])

    defparsec :local_traverse,
              literal("T")
              |> integer(2)
              |> traverse(@three_ascii_letters, {:private_join_and_wrap, ["-"]})
              |> integer(2)

    test "returns ok/error" do
      assert local_traverse("T12abc34") == {:ok, ["T", 12, "99-98-97", 34], "", 1, 9}

      error =
        "expected literal \"T\", followed by byte in the range ?0..?9, followed by byte in the range ?0..?9"

      assert local_traverse("Tabc34") == {:error, error, "Tabc34", 1, 1}

      error = "expected byte in the range ?0..?9, followed by byte in the range ?0..?9"
      assert local_traverse("T12abcdf") == {:error, error, "df", 1, 7}

      error =
        "expected byte in the range ?a..?z, followed by byte in the range ?a..?z, followed by byte in the range ?a..?z"

      assert local_traverse("T12ab34") == {:error, error, "ab34", 1, 4}
    end

    test "is not bound" do
      assert not_bound?(traverse(@three_ascii_letters, {:public_join_and_wrap, ["-"]}))
    end

    defp private_join_and_wrap(args, joiner) do
      args |> Enum.join(joiner) |> List.wrap()
    end
  end

  describe "remote map/3 combinator" do
    defparsec :remote_map,
              ascii_char([?a..?z])
              |> ascii_char([?a..?z])
              |> ascii_char([?a..?z])
              |> map({Integer, :to_string, []})

    defparsec :empty_map, map(empty(), {Integer, :to_string, []})

    test "returns ok/error" do
      assert remote_map("abc") == {:ok, ["97", "98", "99"], "", 1, 4}
      assert remote_map("abcd") == {:ok, ["97", "98", "99"], "d", 1, 4}
      assert {:error, _, "1abcd", 1, 1} = remote_map("1abcd")
    end

    test "can map empty" do
      assert empty_map("abc") == {:ok, [], "abc", 1, 1}
    end
  end

  describe "local map/3 combinator" do
    defparsec :local_map,
              ascii_char([?a..?z])
              |> ascii_char([?a..?z])
              |> ascii_char([?a..?z])
              |> map({:local_to_string, []})

    test "returns ok/error" do
      assert local_map("abc") == {:ok, ["97", "98", "99"], "", 1, 4}
      assert local_map("abcd") == {:ok, ["97", "98", "99"], "d", 1, 4}
      assert {:error, _, "1abcd", 1, 1} = local_map("1abcd")
    end

    defp local_to_string(arg) do
      Integer.to_string(arg)
    end
  end

  describe "remote reduce/3 combinator" do
    defparsec :remote_reduce,
              ascii_char([?a..?z])
              |> ascii_char([?a..?z])
              |> ascii_char([?a..?z])
              |> reduce({Enum, :join, ["-"]})

    defparsec :empty_reduce, reduce(empty(), {Enum, :join, ["-"]})

    test "returns ok/error" do
      assert remote_reduce("abc") == {:ok, ["97-98-99"], "", 1, 4}
      assert remote_reduce("abcd") == {:ok, ["97-98-99"], "d", 1, 4}
      assert {:error, _, "1abcd", 1, 1} = remote_reduce("1abcd")
    end

    test "can reduce empty" do
      assert empty_reduce("abc") == {:ok, [""], "abc", 1, 1}
    end
  end

  describe "local reduce/3 combinator" do
    defparsec :local_reduce,
              ascii_char([?a..?z])
              |> ascii_char([?a..?z])
              |> ascii_char([?a..?z])
              |> reduce({:local_join, ["-"]})

    test "returns ok/error" do
      assert local_reduce("abc") == {:ok, ["97-98-99"], "", 1, 4}
      assert local_reduce("abcd") == {:ok, ["97-98-99"], "d", 1, 4}
      assert {:error, _, "1abcd", 1, 1} = local_reduce("1abcd")
    end

    defp local_join(list, joiner) do
      Enum.join(list, joiner)
    end
  end

  describe "concat/2 combinator" do
    defparsec :concat_digit_upper_lower_plus,
              concat(
                concat(ascii_char([?0..?9]), ascii_char([?A..?Z])),
                concat(ascii_char([?a..?z]), ascii_char([?+..?+]))
              )

    test "returns ok/error" do
      assert concat_digit_upper_lower_plus("1Az+") == {:ok, [?1, ?A, ?z, ?+], "", 1, 5}
    end
  end

  describe "repeat/2 combinator" do
    defparsec :repeat_digits, repeat(ascii_char([?0..?9]))

    ascii_to_string = map(ascii_char([?0..?9]), {:to_string, []})
    defparsec :repeat_digits_to_string, repeat(ascii_to_string)

    defparsec :repeat_digits_to_same_inner,
              repeat(map(ascii_to_string, {String, :to_integer, []}))

    defparsec :repeat_digits_to_same_outer,
              map(repeat(ascii_to_string), {String, :to_integer, []})

    test "returns ok/error" do
      assert repeat_digits("123") == {:ok, [?1, ?2, ?3], "", 1, 4}
      assert repeat_digits("a123") == {:ok, [], "a123", 1, 1}
    end

    test "returns ok/error with map" do
      assert repeat_digits_to_string("123") == {:ok, ["49", "50", "51"], "", 1, 4}
    end

    test "returns ok/error with inner and outer map" do
      assert repeat_digits_to_same_inner("123") == {:ok, [?1, ?2, ?3], "", 1, 4}
      assert repeat_digits_to_same_outer("123") == {:ok, [?1, ?2, ?3], "", 1, 4}
    end
  end

  describe "choice/2 combinator" do
    defparsec :simple_choices,
              choice([ascii_char([?a..?z]), ascii_char([?A..?Z]), ascii_char([?0..?9])])

    defparsec :choices_inner_repeat,
              choice([repeat(ascii_char([?a..?z])), repeat(ascii_char([?A..?Z]))])

    defparsec :choices_outer_repeat, repeat(choice([ascii_char([?a..?z]), ascii_char([?A..?Z])]))

    defparsec :choices_repeat_and_inner_map,
              repeat(
                choice([
                  map(ascii_char([?a..?z]), {:to_string, []}),
                  map(ascii_char([?A..?Z]), {:to_string, []})
                ])
              )

    defparsec :choices_repeat_and_maps,
              map(
                repeat(
                  choice([
                    map(ascii_char([?a..?z]), {:to_string, []}),
                    map(ascii_char([?A..?Z]), {:to_string, []})
                  ])
                ),
                {String, :to_integer, []}
              )

    defparsec :choices_with_empty,
              choice([
                ascii_char([?a..?z]),
                empty()
              ])

    @error "expected one of byte in the range ?a..?z, byte in the range ?A..?Z, byte in the range ?0..?9"

    test "returns ok/error" do
      assert simple_choices("a=") == {:ok, [?a], "=", 1, 2}
      assert simple_choices("A=") == {:ok, [?A], "=", 1, 2}
      assert simple_choices("0=") == {:ok, [?0], "=", 1, 2}
      assert simple_choices("+=") == {:error, @error, "+=", 1, 1}
    end

    test "returns ok/error with repeat inside" do
      assert choices_inner_repeat("az") == {:ok, [?a, ?z], "", 1, 3}
      assert choices_inner_repeat("AZ") == {:ok, [], "AZ", 1, 1}
    end

    test "returns ok/error with repeat outside" do
      assert choices_outer_repeat("az") == {:ok, [?a, ?z], "", 1, 3}
      assert choices_outer_repeat("AZ") == {:ok, [?A, ?Z], "", 1, 3}
      assert choices_outer_repeat("aAzZ") == {:ok, [?a, ?A, ?z, ?Z], "", 1, 5}
    end

    test "returns ok/error with repeat and inner map" do
      assert choices_repeat_and_inner_map("az") == {:ok, ["97", "122"], "", 1, 3}
      assert choices_repeat_and_inner_map("AZ") == {:ok, ["65", "90"], "", 1, 3}
      assert choices_repeat_and_inner_map("aAzZ") == {:ok, ["97", "65", "122", "90"], "", 1, 5}
    end

    test "returns ok/error with repeat and maps" do
      assert choices_repeat_and_maps("az") == {:ok, [?a, ?z], "", 1, 3}
      assert choices_repeat_and_maps("AZ") == {:ok, [?A, ?Z], "", 1, 3}
      assert choices_repeat_and_maps("aAzZ") == {:ok, [?a, ?A, ?z, ?Z], "", 1, 5}
    end

    test "returns ok/error on empty" do
      assert choices_with_empty("az") == {:ok, [?a], "z", 1, 2}
      assert choices_with_empty("AZ") == {:ok, [], "AZ", 1, 1}
    end
  end

  describe "optional/2 combinator" do
    defparsec :optional_ascii, optional(ascii_char([?a..?z]))

    test "returns ok/error on empty" do
      assert optional_ascii("az") == {:ok, [?a], "z", 1, 2}
      assert optional_ascii("AZ") == {:ok, [], "AZ", 1, 1}
    end
  end

  describe "custom datetime/2 combinator" do
    date =
      integer(4)
      |> ignore(literal("-"))
      |> integer(2)
      |> ignore(literal("-"))
      |> integer(2)

    time =
      integer(2)
      |> ignore(literal(":"))
      |> integer(2)
      |> ignore(literal(":"))
      |> integer(2)

    defparsec :datetime, date |> ignore(literal("T")) |> concat(time)

    test "returns ok/error by itself" do
      assert datetime("2010-04-17T14:12:34") == {:ok, [2010, 4, 17, 14, 12, 34], "", 1, 20}
    end
  end

  defp bound?(document) do
    {defs, _} = NimbleParsec.Compiler.compile(:not_used, document, [])

    assert length(defs) == 3,
           "Expected #{inspect(document)} to contain 3 clauses, got #{length(defs)}"
  end

  defp not_bound?(document) do
    {defs, _} = NimbleParsec.Compiler.compile(:not_used, document, [])

    assert length(defs) != 3, "Expected #{inspect(document)} to contain more than 3 clauses"
  end
end
