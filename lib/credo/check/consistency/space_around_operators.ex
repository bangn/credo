defmodule Credo.Check.Consistency.SpaceAroundOperators do
  @moduledoc """
  """

  @explanation [check: @moduledoc]
  @code_patterns [
    Credo.Check.Consistency.SpaceAroundOperators.WithSpace,
    Credo.Check.Consistency.SpaceAroundOperators.WithoutSpace
  ]
  @default_params [ignore: [:|]]

  alias Credo.Check.Consistency.Helper
  alias Credo.Check.PropertyValue

  use Credo.Check, run_on_all: true, base_priority: :high

  # TODO: add *ignored* operators, so you can add "|" and still write
  #       [head|tail] while enforcing 2 + 3 / 1 ...

  @doc false
  def run(source_files, params \\ []) when is_list(source_files) do
    source_files
    |> Helper.run_code_patterns(@code_patterns, params)
    |> Helper.add_issues_to_source_files(&issue_for/5, params)
  end

  defp issue_for(_issue_meta, _actual_props, nil, _picked_count, _total_count), do: nil
  defp issue_for(_issue_meta, [], _expected_prop, _picked_count, _total_count), do: nil
  defp issue_for(issue_meta, actual_prop, expected_prop, _picked_count, _total_count) do
    line_no = PropertyValue.meta(actual_prop, :line_no)
    column = PropertyValue.meta(actual_prop, :column)
    trigger = PropertyValue.meta(actual_prop, :trigger)
    actual_prop = PropertyValue.get(actual_prop)

    line = issue_meta |> IssueMeta.source_file() |> SourceFile.line_at(line_no)
    params = issue_meta |> IssueMeta.params()
    ignored_triggers = params |> Params.get(:ignore, @default_params)

    if !Enum.member?(ignored_triggers, trigger) && create_issue?(line, column, trigger) do
      format_issue issue_meta,
        message: message_for(actual_prop, expected_prop),
        line_no: line_no,
        column: column,
        trigger: trigger
    end
  end

  defp message_for(:with_space, :without_space) do
    "There are no spaces around operators most of the time, but here there are."
  end
  defp message_for(:without_space, :with_space) do
    "There are spaces around operators most of the time, but not here."
  end

  # Don't create issues for `&Mod.fun/4`
  defp create_issue?(line, column, :/) do
    ~r/\&[a-zA-Z0-9\.\_\?\!]+\/\d+/     # pattern to detect &Mod.fun/4
    |> Regex.run(line, return: :index)
    |> List.wrap
    |> Enum.any?(fn({start_index, end_index}) ->
        start_index < column && end_index > column
      end)
  end
  # Don't create issues for `c = -1`
  defp create_issue?(line, column, operator) when operator in [:+, :-] do
    !number_with_sign?(line, column) && !number_in_range?(line, column)
  end
  defp create_issue?(_, _, _), do: true

  defp number_with_sign?(line, column) do
    line
    |> String.slice(0..column-2) # -2 because we need to substract the operator
    |> String.match?(~r/[\{\[\(\,\:\=]\s*$/)
  end

  defp number_in_range?(line, column) do
    line
    |> String.slice(column..-1)
    |> String.match?(~r/^\d+\.\./)
  end
end
