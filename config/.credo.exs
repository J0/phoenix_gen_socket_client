%{
  configs: [
    %{
      name: "default",
      files: %{
        included:
          case Mix.env do
            :dev -> ["lib/"]
            :test -> ["test/"]
          end,
        excluded: []
      },
      checks: [
        {Credo.Check.Consistency.ExceptionNames},
        {Credo.Check.Consistency.SpaceInParentheses},
        {Credo.Check.Consistency.SpaceAroundOperators},
        {Credo.Check.Consistency.TabsOrSpaces},
        {Credo.Check.Readability.PredicateFunctionNames},
        {Credo.Check.Readability.TrailingBlankLine},
        {Credo.Check.Readability.TrailingWhiteSpace},
        {Credo.Check.Readability.MaxLineLength, max_length: 120},
        {Credo.Check.Readability.VariableNames},
        {Credo.Check.Warning.IExPry},
        {Credo.Check.Warning.IoInspect}
      ] ++ case Mix.env do
        :dev ->
          [
            {Credo.Check.Readability.ModuleDoc}
          ]
        :test -> []
      end
    }
  ]
}
