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
    brew rmtree [--force] formula1 [formula2] [formula3]... [--ignore formulaX]

    Examples:

      brew rmtree gcc44 gcc48    # Removes 'gcc44' and 'gcc48' and their dependencies
      brew rmtree --force python # Force the removal of a package even if other formulae depend on it
      brew rmtree meld --ignore python  # Remove meld, but don't remove its dependency of python

  OPTIONS
    --force   Overrides the dependency check for just the top-level formula you
              are trying to remove. If you try to remove 'ruby' for example,
              you most likely will not be able to do this because other fomulae
              specify this as a dependency. This option will let you remove
              'ruby'. This will NOT bypass dependency checks for the formula's
              children. If 'ruby' depends on 'git', then 'git' will still not
              be removed.
    --ignore  Ignore some dependencies from removal. This option must appear after
              the formulae to remove.

  EOS

  # TODO: dry-run completely broken. Much more complicated than what I anticipated.
  # => Since none of the formulae get removed, it causes subsequent commands to 
  # => return inaccurate output. For dry-runs, a dependency graph has to be generated
  # => before starting the removal code so it can know ahead of time which users
  # => of a keg are going to be removed later and shouldn't be counted.
  # => This problem also exists for non-dry-runs, so it will need to be addressed soon.
  # => If there is a circular dependency, then they won't get removed even if it is safe to,
  # => because it will always looks like something is using that keg. Interesting issue.
  # => But these are the types of problems that come up with simple scripts for complicated
  # => problems.

  # --dry-run Does a dry-run. Goes through the whole process without actually
  #             removing anything. This gives you a chance to observe what packages
  #             would be removed and a chance to ignore them when you do it for real.

  @dry_run = false


  module_function

  def bash(command)
    escaped_command = Shellwords.escape(command)
    return %x! bash -c #{escaped_command} !
  end

  def remove_keg(keg_name)
    if !@dry_run
      # Remove old versions of keg
      puts bash "brew cleanup #{keg_name}"

      # Remove current keg
      puts bash "brew uninstall #{keg_name}"
    end
  end

  def deps(keg_name)
    if !@dry_run
      deps = bash "join <(sort <(brew leaves)) <(sort <(brew deps #{keg_name}))"
    else
      deps = bash "sort <(brew deps --installed #{keg_name})"
    end
    deps.split("\n")
  end

  def reverse_deps(keg_name)
    reverse_deps = bash "brew uses --installed #{keg_name}"
    reverse_deps = reverse_deps.split("\n")
    if @dry_run
      # Because none of the kegs have actually been removed they will still show up as users
      # TODO: Rewrite. The entire list of kegs to be removed needs to be subtracted out
      reverse_deps = reverse_deps.reject { |x| x.end_with?() }
    end
    reverse_deps
  end

  def rmtree(keg_name, force=false, ignored_kegs=[])
    # Check if anything currently installed uses the keg
    reverse_deps = reverse_deps(keg_name)

    if !force and reverse_deps.length > 0
      puts "Not removing #{keg_name} because other installed kegs depend on it:"
      puts reverse_deps.join("\n")
      puts ""
    else
      # Nothing claims to depend on it
      if ignored_kegs.include? keg_name
        puts "Skipping #{keg_name} because it is ignored"
      else
        puts "Removing #{keg_name}..."
        remove_keg(keg_name)

        deps = deps(keg_name)
        if deps.length > 0
          puts "Found lingering dependencies:"
          puts deps.join("\n")

          deps.each do |dep|
            puts "Removing dependency #{dep}..."
            rmtree dep, false, ignored_kegs
          end
        else
          puts "No dependencies left on system for #{keg_name}."
        end
      end
    end
  end

  def main
    force = false
    ignored_kegs = []
    rm_kegs = []

    if ARGV.size < 1 or ['-h', '?', '--help'].include? ARGV.first
      puts USAGE
      exit 0
    end

    raise KegUnspecifiedError if ARGV.named.empty?

    loop { case ARGV[0]
        when '--dry-run' then ARGV.shift; @dry_run = true
        when '--force' then  ARGV.shift; force = true
        when '--ignore' then  ARGV.shift; ignored_kegs.push(*ARGV); break
        when /^-/ then  puts "Unknown option: #{ARGV.shift.inspect}"; puts USAGE
        when /^[^-]/ then rm_kegs.push(ARGV.shift)
        else break
    end; }

    if @dry_run
      #puts "** DRY RUN **"; puts ""
      puts "ERROR: dry-run currently in development"
      puts ""
      puts USAGE
      exit 0
    end

    rm_kegs.each { |keg_name| rmtree keg_name, force, ignored_kegs }
  end
end

BrewRmtree.main
exit 0
