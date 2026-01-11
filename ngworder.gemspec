# frozen_string_literal: true

require_relative "lib/ngworder/version"

Gem::Specification.new do |spec|
  spec.name = "ngworder"
  spec.version = Ngworder::VERSION
  spec.summary = "Extract NG words from Japanese text using simple rule files"
  spec.description = "CLI tool to scan files for NG words with per-rule exclusions."
  spec.authors = ["Masanori Kado"]
  spec.email = ["kdmsnr@gmail.com"]
  spec.license = "MIT"
  spec.files = Dir.glob("{bin,lib}/**/*") + ["AGENTS.md", "NGWORDS.txt", "LICENSE", "README.md"]
  spec.executables = ["ngworder"]
  spec.required_ruby_version = ">= 2.7"
end
