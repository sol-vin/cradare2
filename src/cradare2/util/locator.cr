module Cradare2
  module Util
    # Cross-platform utility for locating radare2 binaries.
    module Locator
      DEFAULT_BINARY_NAMES = ["r2", "radare2"]

      # Finds the path to the radare2 binary, checking custom override,
      # environment variables, PATH, and standard operating system installation locations.
      def self.find_r2(custom_path : String? = nil) : String
        if custom_path && !custom_path.empty?
          return custom_path if File.exists?(custom_path)
          if found = Process.find_executable(custom_path)
            return found
          end
          raise BinaryNotFoundError.new("Specified radare2 executable not found: #{custom_path}")
        end

        # Check environment variables
        {% for env_var in ["RADARE2_PATH", "R2PIPE_R2", "R2_PATH"] %}
          if (env_val = ENV[{{env_var}}]?) && !env_val.empty?
            return env_val if File.exists?(env_val)
            if found = Process.find_executable(env_val)
              return found
            end
          end
        {% end %}

        # Check PATH via Process.find_executable
        DEFAULT_BINARY_NAMES.each do |name|
          if path = Process.find_executable(name)
            return path
          end
        end

        # Platform-specific fallback paths
        {% if flag?(:windows) %}
          windows_candidates = [] of String
          if user_profile = ENV["USERPROFILE"]?
            windows_candidates << File.join(user_profile, "scoop", "shims", "r2.exe")
            windows_candidates << File.join(user_profile, "scoop", "apps", "radare2", "current", "r2.exe")
            windows_candidates << File.join(user_profile, "scoop", "apps", "radare2", "current", "bin", "radare2.exe")
          end
          if choco = ENV["ChocolateyInstall"]?
            windows_candidates << File.join(choco, "bin", "r2.exe")
            windows_candidates << File.join(choco, "bin", "radare2.exe")
          end
          if prog_files = ENV["ProgramFiles"]?
            windows_candidates << File.join(prog_files, "radare2", "bin", "radare2.exe")
            windows_candidates << File.join(prog_files, "radare2", "bin", "r2.exe")
          end
          windows_candidates.each do |cand|
            return cand if File.exists?(cand)
          end
        {% else %}
          unix_candidates = [
            "/usr/bin/r2",
            "/usr/local/bin/r2",
            "/opt/homebrew/bin/r2",
            "/usr/bin/radare2",
            "/usr/local/bin/radare2",
            "/opt/homebrew/bin/radare2",
            File.expand_path("~/bin/r2"),
            File.expand_path("~/.local/bin/r2"),
          ]
          unix_candidates.each do |cand|
            return cand if File.exists?(cand)
          end
        {% end %}

        raise BinaryNotFoundError.new(
          "Could not locate 'radare2' or 'r2' executable in PATH or standard installation directories. " \
          "Please install radare2 or set RADARE2_PATH environment variable."
        )
      end
    end
  end
end
