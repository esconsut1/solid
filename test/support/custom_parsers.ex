defmodule CustomDateParser do
  @moduledoc false
  use Solid.Parser.Base,
    custom_tags: [
      CustomTags.CurrentDate,
      CustomTags.GetYearOfDate,
      CustomTags.CustomBrackedWrappedTag
    ]
end

defmodule CustomFooParser do
  @moduledoc false
  use Solid.Parser.Base,
    custom_tags: [CustomTags.FoobarTag, CustomTags.FoobarValTag]
end

defmodule NoRenderParser do
  @moduledoc false
  use Solid.Parser.Base, excluded_tags: [Solid.Tag.Render]
end
