require 'test_helper'

describe 'Seedbank rake.task' do

  describe "seeds with dependency" do

    subject { Rake.application.tasks_in_scope(defined?(Rake::Scope) ? Rake::Scope.new('db:seed') : %w[db seed]) }

    it "creates all the seed tasks" do
      seeds = %w(db:seed:circular1 db:seed:circular2 db:seed:common
        db:seed:common_seeds
        db:seed:common_seeds:common_file
        db:seed:common_seeds:first_level
        db:seed:common_seeds:first_level:first_level_dependent db:seed:common_seeds:first_level:first_level_file
        db:seed:common_seeds:first_level:second_level
        db:seed:common_seeds:first_level:second_level:second_level_file 
        db:seed:common_seeds:first_level:second_level:third_level
        db:seed:common_seeds:first_level:second_level:third_level:third_level_dependent
        db:seed:common_seeds:first_level:second_level:third_level:third_level_file
        db:seed:dependency 
        db:seed:dependency2 db:seed:dependent db:seed:dependent_on_nested
        db:seed:dependent_on_several
        db:seed:development 
        db:seed:development:shared db:seed:development:shared:accounts
        db:seed:development:users
        db:seed:no_block
        db:seed:original)

      subject.map(&:to_s).must_equal seeds
    end
  end

  describe "common seeds" do

    Dir[File.expand_path('../../../dummy/db/seeds/*.seeds.rb', __FILE__)].each do |seed_file|
      seed = File.basename(seed_file, '.seeds.rb')

      describe seed do

        subject { Rake.application.lookup(['db', 'seed', seed].join(':')) }

        it "is dependent on db:abort_if_pending_migrations" do
          subject.prerequisites.must_equal %w[db:abort_if_pending_migrations]
        end
      end
    end
  end

  describe "db:seed:common" do

    subject { Rake::Task['db:seed:common'] }

    it "is dependent on the common seeds and db:seed:original" do
      db_seeds_root_common = Dir[File.expand_path('../../../dummy/db/seeds', __FILE__) + "/*.seeds.rb"].sort.map do |seed_file|
        ['db', 'seed', File.basename(seed_file, '.seeds.rb')].join(':')
      end
      
      db_seeds_common_dir = Dir[File.expand_path("../../../dummy/db/seeds/common_seeds", __FILE__) + "/**/*"].sort.map do |seed_file|

        dirname = Pathname.new(seed_file).dirname
        relative = dirname.relative_path_from(Pathname.new(File.expand_path("../../../dummy/db/seeds", __FILE__)))
        scopes  = relative.to_s.split(File::Separator)

        ['db', 'seed', scopes, File.basename(seed_file, '.seeds.rb')].join(':')
      end
      
      prerequisite_seeds = ['db:seed:original'] + db_seeds_root_common + db_seeds_common_dir

      subject.prerequisites.must_equal prerequisite_seeds
    end
  end

  describe "db:seed:original" do

    subject { Rake::Task['db:seed:original'] }

    it "has no dependencies" do
      subject.prerequisites.must_equal %w[db:abort_if_pending_migrations]
    end

    describe "when seeds are reloaded" do

      before do
        Dummy::Application.load_tasks
      end

      it "still has no dependencies" do
        subject.prerequisites.must_equal %w[db:abort_if_pending_migrations]
      end
    end
  end

  describe "environment seeds" do

    Dir[File.expand_path('../../../dummy/db/seeds', __FILE__) + '/*/'].each do |environment_directory|
      unless environment_directory == 'common_seeds'
        environment = File.basename(environment_directory)

        describe "seeds in the #{environment} environment" do
          Dir[File.expand_path("../../../dummy/db/seeds/#{environment}", __FILE__) + "/*.seeds.rb"].each do |seed_file|
            seed = File.basename(seed_file, ".seeds.rb")

            describe seed do
              subject { Rake.application.lookup(['db', 'seed', environment, seed].join(':')) }

              it "is dependent on db:abort_if_pending_migrations" do
                subject.prerequisites.must_equal %w[db:abort_if_pending_migrations]
              end
            end
          end
        end

        describe "db:seed:#{environment}" do

          subject { Rake.application.lookup(['db', 'seed', environment].join(':')) }

          it "is dependent on the seeds in the environment directory" do
            prerequisite_seeds = Dir[File.expand_path("../../../dummy/db/seeds/#{environment}", __FILE__) + "/**/*"].sort.map do |seed_file|

              dirname = Pathname.new(seed_file).dirname
              relative = dirname.relative_path_from(Pathname.new(File.expand_path("../../../dummy/db/seeds", __FILE__)))
              scopes  = relative.to_s.split(File::Separator)

              ['db', 'seed', scopes, File.basename(seed_file, '.seeds.rb')].join(':')
            end.unshift('db:seed:common')

            subject.prerequisites.must_equal prerequisite_seeds
          end
        end
      end
    end
  end

  describe "db:seed task" do

    subject { Rake::Task['db:seed'] }

    describe "when no environment seeds are defined" do

      it "is dependent on db:seed:common" do
        subject.prerequisites.must_equal %w[db:seed:common]
      end
    end

    describe "when environment seeds are defined" do

      it "is dependent on db:seed:common" do
        flexmock(Rails).should_receive(:env).and_return('development').once

        Rake.application.clear
        Dummy::Application.load_tasks

        subject.prerequisites.must_equal %w[db:seed:common db:seed:development]
      end
    end
  end
end

# prerequisite_seeds = Pathname.glob(File.expand_path('../../../dummy/db/seeds/all_envs/**/*.seeds.rb', __FILE__)).sort.map do |seed_files|
#   seed_files.relative_path_from(Pathname.new(File.expand_path('../../../dummy/db/seeds/all_envs', __FILE__)).dirname.split.map do |d| 
#     if d.to_s == "."
#       ['db', 'seed', 'all_envs', File.basename(seed_files, '.seeds.rb')].join(':')
#     else
#       ['db', 'seed', 'all_envs', d.to_s.gsub("/",":") , File.basename(seed_files, '.seeds.rb')].join(':')
#     end
#   end
# end

