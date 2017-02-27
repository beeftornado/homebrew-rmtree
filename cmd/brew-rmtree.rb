#:
#:  * `rmtree` [`--force`] [`--dry-run`] [`--quiet`] formula1 [formula2] [formula3]... [`--ignore` formulaX]
#:
#:    Remove a formula entirely, including all of its dependencies,
#:    unless of course, they are used by another formula.
#:
#:    Warning:
#:
#:      Not all formulae declare their dependencies and therefore this command may end
#:      up removing something you still need. It should be used with caution.
#:
#:    With `--force`, you can override the dependency check for the top-level formula you
#:    are trying to remove. If you try to remove 'ruby' for example, you most likely will
#:    not be able to do this because other fomulae specify this as a dependency. This
#:    option will let you remove 'ruby'. This will NOT bypass dependency checks for the
#:    formula's children. If 'ruby' depends on 'git', then 'git' will still not be removed.
#:
#:    With `--ignore`, you can ignore some dependencies from being removed. This option
#:    must come after the formulae to remove.
#:
#:    You can use `--dry-run` to see what would be removed without actually removing
#:    anything.
#:
#:    `--quiet` will hide output.
#:
#:    `brew rmtree` <formula>
#:    Removes <formula> and its dependencies.
#:
#:    `brew rmtree` <formula> <formula2>
#:    Removes <formula> and <formula2> and their dependencies.
#:
#:    `brew rmtree` --force <formula>
#:    Force the removal of <formula> even if other formulae depend on it.
#:
#:    `brew rmtree` <formula> --ignore <formula2>
#:    Remove <formula>, but don't remove it's dependency of <formula2>

require 'keg'
require 'formula'
require 'shellwords'
require 'set'
require 'cmd/deps'

# I am not a ruby-ist and so my style may offend some

module BrewRmtree

  @dry_run = false
  @used_by_table = {}
  @dependency_table = {}

  module_function

  def bash(command)
    escaped_command = Shellwords.escape(command)
    return %x! bash -c #{escaped_command} !
  end

  # replaces Kernel#puts w/ do-nothing method
  def puts_off
    Kernel.module_eval %q{
      def puts(*args)
      end
      def print(*args)
      end
    }
  end

  # restores Kernel#puts to its original definition
  def puts_on
    Kernel.module_eval %q{
      def puts(*args)
        $stdout.puts(*args)
      end
      def print(*args)
        $stdout.print(*args)
      end
    }
  end

  # Sets the text to output with the spinner
  def set_spinner_progress(txt)
    @spinner[:progress] = txt
  end

  def show_wait_spinner(fps=10)
    chars = %w[| / - \\]
    delay = 1.0/fps
    iter = 0
    @spinner = Thread.new do
      Thread.current[:progress] = ""
      progress_size = 0
      while iter do  # Keep spinning until told otherwise
        print ' ' + chars[(iter+=1) % chars.length] + Thread.current[:progress]
        progress_size = Thread.current[:progress].length
        sleep delay
        print "\b"*(progress_size + 2)
      end
    end
    yield.tap{       # After yielding to the block, save the return value
      iter = false   # Tell the thread to exit, cleaning up after itself…
      @spinner.join   # …and wait for it to do so.
    }                # Use the block's return value as the method's
  end

  # Remove a particular keg
  def remove_keg(keg_name)
    # Remove old versions of keg
    puts bash "brew cleanup #{keg_name}"

    # Remove current keg
    puts bash "brew uninstall --ignore-dependencies #{keg_name}"
  end

  # A list of dependencies of keg_name that are still installed after removal
  # of the keg
  def orphaned_dependencies(keg_name)
    bash("join <(sort <(brew leaves)) <(sort <(brew deps #{keg_name}))").split("\n")
  end

  # A list of kegs that use keg_name, using homebrew code instead of shell cmd
  def uses(keg_name, recursive=true, ignores=[])
    # https://github.com/Homebrew/homebrew/blob/master/Library/Homebrew/cmd/uses.rb
    formulae = [Formulary.factory(keg_name)]
    uses = Formula.installed.select do |f|
      formulae.all? do |ff|
        begin
          if recursive
            deps = f.recursive_dependencies do |dependent, dep|
              Dependency.prune if ignores.any? { |ignore| dep.send(ignore) } && !dependent.build.with?(dep)
            end
            reqs = f.recursive_requirements do |dependent, req|
              Requirement.prune if ignores.any? { |ignore| req.send(ignore) } && !dependent.build.with?(req)
            end
            deps.any? { |dep| dep.to_formula.full_name == ff.full_name rescue dep.name == ff.name } ||
              reqs.any? { |req| req.name == ff.name || [ff.name, ff.full_name].include?(req.default_formula) }
          else
            deps = f.deps.reject do |dep|
              ignores.any? { |ignore| dep.send(ignore) }
            end
            reqs = f.requirements.reject do |req|
              ignores.any? { |ignore| req.send(ignore) }
            end
            deps.any? { |dep| dep.to_formula.full_name == ff.full_name rescue dep.name == ff.name } ||
              reqs.any? { |req| req.name == ff.name || [ff.name, ff.full_name].include?(req.default_formula) }
          end
        rescue FormulaUnavailableError
          # Silently ignore this case as we don't care about things used in
          # taps that aren't currently tapped.
        end
      end
    end
    uses.map(&:full_name)
  end

  # Gather complete list of packages used by root package
  def dependency_tree(keg_name, recursive=true)
    Homebrew.deps_for_formula(as_formula(keg_name), recursive
      ).map{ |x| as_formula(x) }
      .select(&:installed?
      )#.sort_by(&:name)
  end

  # Returns a set of dependencies as their keg name
  def dependency_tree_as_keg_names(keg_name, recursive=true)
    @dependency_table[keg_name] ||= dependency_tree(keg_name, recursive).map!(&:name)
  end

  # Return a formula for keg_name
  def as_formula(keg_name)
    if keg_name.is_a? Dependency
      return Formulary.factory(keg_name.name)
    end
    if keg_name.is_a? Requirement
      return Formulary.factory(keg_name.to_dependency.name)
    end
    return Formulary.factory(keg_name)
  end

  def used_by(dep_name, del_formula)
    @used_by_table[dep_name] ||= uses(dep_name, false).to_set.delete(del_formula.full_name)
  end

  # Return list of installed formula that will still use this dependency
  # after deletion and thus cannot be removed.
  def still_used_by(dep_name, del_formula, full_dep_list)
    # List of formulae that use this keg and aren't in the tree
    # of dependencies to be removed
    return used_by(dep_name, del_formula).subtract(full_dep_list)
  end

  def cant_remove(dep_set)
    !dep_set.empty?
  end

  def can_remove(dep_set)
    dep_set.empty?
  end

  def removable_in_tree(tree)
    tree.select {|dep,used_by_set| can_remove(used_by_set)}
  end

  def unremovable_in_tree(tree)
    tree.select {|dep,used_by_set| cant_remove(used_by_set)}
  end

  def describe_build_tree_will_remove(tree)
    will_remove = removable_in_tree(tree)

    puts ""
    puts "Can safely be removed"
    puts "----------------------"
    puts will_remove.map { |dep,_| dep }.sort.join("\n")
  end

  def describe_build_tree_wont_remove(tree)
    wont_remove = unremovable_in_tree(tree)

    puts ""
    puts "Won't be removed"
    puts "-----------------"
    puts wont_remove.map { |dep,used_by| "#{dep} is used by #{used_by.to_a.join(', ')}" }.sort.join("\n")
  end

  # Print out interpretation of dependency analysis
  def describe_build_tree(tree)
    describe_build_tree_will_remove(tree)
    describe_build_tree_wont_remove(tree)
  end

  # Simple prompt helper
  def should_proceed(prompt)
    input = [(print "#{prompt}[y/N]: "), gets.rstrip][1]
    if ['y', 'yes'].include?(input.downcase)
      return true
    end
    return false
  end

  def should_proceed_or_quit(prompt)
    puts ""
    unless should_proceed(prompt)
      puts ""
      onoe "User quit"
      exit 0
    end
    return true
  end

  # Will mark any children and parents of dep as unremovable if dep is unremovable
  def revisit_neighbors(of_dependency, del_formula, dep_set, wont_remove_because)
    # Prevent subsequent related formula from being flagged for removal
    dep_set.delete(of_dependency)

    # Update users of the dependency
    used_by(of_dependency, del_formula).each do |user_of_d|
      # Only update those we visited and think we can remove
      if wont_remove_because.has_key? user_of_d and can_remove(wont_remove_because[user_of_d])
        wont_remove_because[user_of_d] << of_dependency
        revisit_neighbors(user_of_d, del_formula, dep_set, wont_remove_because)
      end
    end

    # Update dependencies of the dependency
    dependency_tree_as_keg_names(of_dependency, false).each do |d|
      # Only update those we visited and think we can remove
      if wont_remove_because.has_key? d and can_remove(wont_remove_because[d])
        wont_remove_because[d] << of_dependency
        revisit_neighbors(d, del_formula, dep_set, wont_remove_because)
      end
    end
  end

  # Walk the tree and decide which ones are safe to remove
  def build_tree(keg_name, ignored_kegs=[])
    # List used to save the status of all dependency packages
    wont_remove_because = {}

    ohai "Examining installed formulae required by #{keg_name}..."
    show_wait_spinner{

      # Convert the keg_name the user provided into homebrew formula
      f = as_formula(keg_name)

      # Get the complete list of dependencies and convert it to just keg names
      dep_arr = dependency_tree_as_keg_names(keg_name)
      dep_set = dep_arr.to_set

      # For each possible dependency that we want to remove, check if anything
      # uses it, which is not also in the list of dependencies. That means it
      # isn't safe to remove.
      dep_arr.each do |dep|

        # Set the progress text for spinner thread
        set_spinner_progress "  #{wont_remove_because.size} / #{dep_arr.length} "

        # Save the list of formulae that use this keg and aren't in the tree
        # of dependencies to be removed
        wont_remove_because[dep] = still_used_by(dep, f, dep_set)

        # Allow user to keep dependencies that aren't used anymore by saying
        # something phony uses it
        if ignored_kegs.include?(dep)
          if wont_remove_because[dep].empty?
            wont_remove_because[dep] << "ignored"
          end
        end

        # Revisit any formulae already visited and related to this dependency
        # because at the time they didn't have this new information
        if cant_remove(wont_remove_because[dep])
          # This dependency can't be removed. Users and dependencies need to be reconsidered.
          revisit_neighbors(dep, f, dep_set, wont_remove_because)
        end

        set_spinner_progress "  #{wont_remove_because.size} / #{dep_arr.length} "
      end
    }
    print "\n"
    return wont_remove_because
  end

  def rmtree(keg_name, force=false, ignored_kegs=[])
    # Does anything use keg such that we can't remove it?
    if !force
      keg_used_by = uses(keg_name, false)
      if !keg_used_by.empty?
        puts "#{keg_name} can't be removed because other formula depend on it:"
        puts keg_used_by.join(", ")
        return
      end
    end

    # Check if the formula is installed (outdated implies installed)
    unless as_formula(keg_name).installed? || as_formula(keg_name).outdated?
      onoe "#{keg_name} is not currently installed"
      return
    end

    # Dependency list of what can be removed, and what can't, and why
    wont_remove_because = build_tree(keg_name, ignored_kegs)

    # Dry run print out more information on what will happen
    if @dry_run
      describe_build_tree(wont_remove_because)
      return
    end

    # Confirm with user packages that can and will be removed
    describe_build_tree_will_remove(wont_remove_because)

    should_proceed_or_quit("Proceed?")

    ohai "Cleaning up packages safe to remove"

    # Remove packages
    remove_keg(keg_name)
    removable_in_tree(wont_remove_because).map { |d,_| remove_keg(d) }
  end

  def main
    force = false
    ignored_kegs = []
    rm_kegs = []
    quiet = false

    if ARGV.size < 1 or ['-h', '?', '--help'].include? ARGV.first
      abort `brew rmtree --help`
    end

    raise KegUnspecifiedError if ARGV.named.empty?

    loop { case ARGV[0]
        when '--quiet' then ARGV.shift; quiet = true
        when '--dry-run' then ARGV.shift; @dry_run = true
        when '--force' then  ARGV.shift; force = true
        when '--ignore' then  ARGV.shift; ignored_kegs.push(*ARGV); break
        when /^-/ then  onoe "Unknown option: #{ARGV.shift.inspect}"; abort `brew rmtree --help`
        when /^[^-]/ then rm_kegs.push(ARGV.shift)
        else break
    end; }

    # Turn off output if 'quiet' is specified
    if quiet
      puts_off
    end

    if @dry_run
      puts "This is a dry-run, nothing will be deleted"
    end

    # Convert ignored kegs into full names
    ignored_kegs.map! { |k| as_formula(k).full_name }

    rm_kegs.each { |keg_name| rmtree keg_name, force, ignored_kegs }
  end
end

BrewRmtree.main
exit 0
