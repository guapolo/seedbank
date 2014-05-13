after "first_level:second_level:second_level_file" do
  FakeModel.seed('dependent on second level seeds')
end