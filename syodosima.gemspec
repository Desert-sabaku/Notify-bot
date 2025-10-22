require_relative "lib/syodosima/version"

Gem::Specification.new do |spec|
  spec.name = "syodosima"
  spec.version = Syodosima::VERSION
  spec.authors = ["SANADA Euki"]
  spec.email = ["yuu.mat.930@gmail.com"]

  spec.summary = "Notify Discord of appointments on a given Google Calendar."
  spec.description = <<~DESC
    A Ruby gem that sends notifications to a Discord channel about events from a specified Google Calendar.
  DESC
  spec.homepage = "https://github.com/Desert-sabaku/syodosima"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/Desert-sabaku/syodosima"
  spec.metadata["changelog_uri"] = "https://github.com/Desert-sabaku/syodosima/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  spec.add_dependency "discordrb", ">= 3.5.0"
  spec.add_dependency "dotenv", ">= 3.1.8"
  spec.add_dependency "google-apis-calendar_v3", ">= 0.53.0"
  spec.add_dependency "pstore", ">= 0.2.0"
  spec.add_dependency "webrick", ">= 1.9.1"
  spec.add_development_dependency "bundler", ">= 2.7.2"
  spec.add_development_dependency "minitest", ">= 5.26.0"
  spec.add_development_dependency "rake", ">= 13.3.0"
  spec.add_development_dependency "rubocop", ">= 1.81.1"
  spec.add_development_dependency "solargraph", ">= 0.57.0"
  spec.add_development_dependency "steep", ">= 1.15.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
