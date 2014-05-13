after "first_level:second_level:third_level:third_level_file" do
  FakeModel.seed('dependent on third level seeds')
end