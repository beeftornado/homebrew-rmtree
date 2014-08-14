require 'keg'
require 'formula'
require 'shellwords'

module BrewRmtree

  USAGE = <<-EOS.undent
  DESCRIPTION
    `rmtree` allows you to remove a formula entirely, including all of its dependencies,
    unless of course, they are used by another formula.

    Warning:

      Not all formulas declare their dependencies and therefore this command may end up
      removing something you still need. It should be used with caution.

  USAGE
    brew rmtree formula1 [formula2] [formula3]...

    Examples:

      brew rmtree gcc44 gcc48   # Removes 'gcc44' and 'gcc48' and their dependencies
  EOS

  module_function

  def bash(command)
    escaped_command = Shellwords.escape(command)
    return %x! bash -c #{escaped_command} !
  end

  def rmtree
    if ARGV.size < 1 or ['-h', '?', '--help'].include? ARGV.first
      puts USAGE
      exit 0
    end

    raise KegUnspecifiedError if ARGV.named.empty?

    if not ARGV.force?
      ARGV.named.each do |keg_name|

        # Remove old versions of keg
        puts bash "brew cleanup #{keg_name}"

        # Remove current keg
        puts bash "brew uninstall #{keg_name}"

        deps = bash "join <(brew leaves) <(brew deps #{keg_name})"

        if deps.length > 0
          puts "Found lingering dependencies"
          puts deps.chomp

          deps = deps.split("\n")

          deps.each do |dep|
            dep = dep.chomp

            if !dep.empty?
              # Check if anything currently installed uses the dependency
              dep_deps = bash "brew uses --installed #{dep}"
              dep_deps = dep_deps.chomp

              if dep_deps.length > 0
                puts "Not removing dependency #{dep} because other installed packages depend on it:"
                puts dep_deps
              else
                # Nothing claims to depend on it
                puts "Removing dependency #{dep}..."
                puts bash "brew rmtree #{dep}"
              end
            end
          end
        else
          puts "No dependencies left on system for #{keg_name}."
        end
      end
    else
      puts "--force is not supported."
    end
  rescue MultipleVersionsInstalledError => e
    ofail e
    puts "Use `brew rmtree --force #{e.name}` to remove all versions."
  end
end

BrewRmtree.rmtree
exit 0
