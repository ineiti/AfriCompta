require 'prawn'
require 'prawn/measurement_extensions'

class Accounts < Entities
  self.needs %w(Users Movements)

  attr_reader :check_state, :check_progress

  def setup_data
    @default_type = :SQLiteAC
    @data_field_id = :id
    value_int :index

    value_str :name
    value_str :desc
    value_str :global_id
    value_float :total
    value_int :multiplier
    value_int :rev_index
    value_bool :deleted
    value_bool :keep_total
    # This is the ID of the parent account
    value_int :account_id
  end

  def self.create(name, desc = 'Too lazy', parent = nil, global_id = '', mult = nil)
    dputs(5) { "Parent is #{parent.inspect}" }
    if parent
      if parent.class != Account && parent != AccountRoot
        parent = Accounts.matches_by_id(parent).first
      end
      mult ||= parent.multiplier
      a = super(:name => name, :desc => desc, :account_id => parent.id,
                :global_id => global_id.to_s, :multiplier => mult,
                :deleted => false, :keep_total => parent.keep_total)
    else
      mult ||= 1
      a = super(:name => name, :desc => desc, :account_id => 0,
                :global_id => global_id.to_s, :multiplier => mult,
                :deleted => false, :keep_total => false)
    end
    a.total = 0
    if global_id == ''
      a.global_id = Users.match_by_name('local').full + '-' + a.id.to_s
    end
    a.new_index
    dputs(2) { "Created account #{a.path_id} - #{a.inspect}" }
    a
  end

  def self.create_path(path, desc = '', double_last = false, mult = 1,
      keep_total = false)
    dputs(3) { "Path: #{path.inspect}, mult: #{mult}" }
    elements = path.split('::')
    parent = AccountRoot
    while elements.size > 0
      name = elements.shift
      dputs(4) { "Working on element #{name} with base of #{parent.path_id}" }
      child = parent.accounts.find { |a|
        dputs(5) { "Searching child #{a.name} - #{a.path_id}" }
        a.name == name
      }
      child and dputs(4) { "Found existing child #{child.path_id}" }
      if (not child) or (elements.size == 0 and double_last)
        dputs(4) { "Creating child #{name}" }
        child = Accounts.create(name, desc, parent)
      end
      parent = child
    end
    parent.set_nochildmult(name, desc, nil, mult, [], keep_total)
  end

  # Gets an account from a string, if it doesn't exist yet, creates it.
  # It will update it anyway.
  def self.from_s(str)
    str.force_encoding(Encoding::UTF_8)
    desc, str = str.split("\r")
    if not str
      dputs(0) { "Error: Invalid account found: #{desc}" }
      return [-1, nil]
    end
    global_id, total, name, multiplier, par,
        deleted_s, keep_total_s = str.split("\t")
    total, multiplier = total.to_f, multiplier.to_f
    deleted = deleted_s == 'true'
    keep_total = keep_total_s == 'true'
    dputs(3) { [global_id, total, name, multiplier].inspect }
    dputs(3) { [par, deleted_s, keep_total_s].inspect }
    dputs(5) { "deleted, keep_total is #{deleted.inspect}, #{keep_total.inspect}" }
    dputs(3) { 'Here comes the account: ' + global_id.to_s }
    dputs(3) { "global_id: #{global_id}" }

    if par.to_s.length > 0
      parent = Accounts.match_by_global_id(par)
      parent_id = parent.id
      dputs(3) { "Parent is #{parent.inspect}" }
    else
      parent = nil
      parent_id = 0
    end

    # Does the account already exist?
    our_a = nil
    if not (our_a = Accounts.match_by_global_id(global_id))
      # Create it
      dputs(3) { "Creating account #{name} - #{desc} - #{parent} - #{global_id}" }
      our_a = Accounts.create(name, desc, parent, global_id)
    end
    # And update it
    our_a.deleted = deleted
    our_a.set_nochildmult(name, desc, parent_id, multiplier, [], keep_total)
    our_a.global_id = global_id
    dputs(2) { "Saved account #{name} with index #{our_a.rev_index} and global_id #{our_a.global_id}" }
    dputs(4) { "Account is now #{our_a.inspect}" }
    return our_a
  end

  def self.get_by_path_or_create(p, desc = '', last = false, mult = 1, keep = false)
    get_by_path(p) or
        create_path(p, desc, last, mult, keep)
  end

  def self.get_by_path(parent, elements = nil)
    if not elements
      if parent
        return get_by_path(AccountRoot, parent.split('::'))
      else
        return nil
      end
    end

    child = elements.shift
    parent.accounts.each { |a|
      if a.name == child
        if elements.length > 0
          return get_by_path(a, elements)
        else
          return a
        end
      end
    }
    return nil
  end

  def self.find_by_path(parent)
    return Accounts.get_by_path(parent)
  end

  def self.get_id_by_path(p)
    if a = get_by_path(p)
      return a.id.to_s
    else
      return nil
    end
  end

  def archive_parent(acc, years_archived, year)
    dputs(3) { "years_archived is #{years_archived.inspect}" }
    if not years_archived.has_key? year
      dputs(2) { "Adding #{year}" }
      years_archived[year] =
          Accounts.create_path("Archive::#{year}", 'New archive')
    end
    # This means we're more than one level below root, so we can't
    # just copy easily
    if acc.path.split('::').count > 2
      dputs(3) { "Creating archive #{acc.path} with mult #{acc.multiplier}" }
      return Accounts.create_path("Archive::#{year}::"+
                                      "#{acc.parent.path.gsub(/^Root::/, '')}", 'New archive', false,
                                  acc.multiplier, acc.keep_total)
    else
      return years_archived[year]
    end
  end

  def search_account(acc, month_start)
    years = Hash.new(0)
    acc.movements.each { |mov|
      if not mov.desc =~ /^-- Sum of/
        y, m, _ = mov.date.to_s.split('-').collect { |d| d.to_i }
        dputs(5) { "Date of #{mov.desc} is #{mov.date}" }
        m < month_start and y -= 1
        years[y] += 1
      end
    }
    dputs(3) { "years is #{years.inspect}" }
    years
  end

  def create_accounts(acc, years, years_archived, this_year)
    years.keys.each { |y|
      if y == this_year
        dputs(3) { "Creating path #{acc.path} with mult #{acc.multiplier}" }
        years[y] = Accounts.create_path(acc.path, acc.desc,
                                        true, acc.multiplier, acc.keep_total)
      else
        path = "#{archive_parent(acc, years_archived, y).path}::" +
            acc.name
        dputs(3) { "Creating other path #{path} with mult #{acc.multiplier}" }
        years[y] = Accounts.create_path(path, acc.desc, false,
                                        acc.multiplier, acc.keep_total)
      end
      dputs(3) { "years[y] is #{years[y].path_id}" }
    }
  end

  def move_movements(acc, years, month_start)
    acc.movements.each { |mov|
      dputs(5) { 'Start of each' }
      y, m, _ = mov.date.to_s.split('-').collect { |d| d.to_i }
      dputs(5) { "Date of #{mov.desc} is #{mov.date}" }
      m < month_start and y -= 1
      if years.has_key? y
        value = mov.value
        mov.value = 0
        dputs(5) { "Moving to #{years[y].inspect}: " +
            "#{mov.account_src.id} - #{mov.account_dst.id} - #{acc.id}" }
        if mov.account_src.id == acc.id
          dputs(5) { 'Moving src' }
          mov.account_src_id = years[y]
        else
          dputs(5) { 'Moving dst' }
          mov.account_dst_id = years[y]
        end
        mov.value = value
      end
    }
    dputs(5) { "Movements left in account #{acc.path}:" }
    acc.movements.each { |m|
      dputs(5) { m.desc }
    }
  end

  def sum_up_total(acc_path, years_archived, month_start)
    a_path = acc_path.sub(/[^:]*::/, '')
    dputs(2) { "Summing up account #{a_path}" }
    acc_sum = []
    years_archived.each { |y, a|
      dputs(5) { "Found archived year #{y.inspect} which is #{y.class.name}" }
      aacc = Accounts.get_by_path(a.get_path + '::' + a_path)
      acc_sum.push [y, a, aacc]
    }
    dputs(5) { 'Trying to add current year' }
    if curr_acc = Accounts.get_by_path(acc_path)
      dputs(4) { 'Adding current year' }
      acc_sum.push [9999, nil, curr_acc]
    end

    last_total = 0
    last_year_acc = nil
    last_year_acc_parent = nil
    last_year = 0
    dputs(5) { "Sorting account_sums #{acc_sum.length}" }
    acc_sum.sort { |a, b| a[0] <=> b[0] }.each { |y, a, aacc|
      dputs(5) { "y, a, aacc: #{y}, #{a.to_json}, #{aacc.to_json}" }
      if aacc
        last_year_acc_parent and last_year_acc_parent.dump true
        dputs(4) { "Found archived account #{aacc.get_path} for year #{y}" +
            " with last_total #{last_total}" }
        dputs(5) { 'And has movements' }
        aacc.movements.each { |m|
          dputs(5) { m.to_json }
        }
        if last_total != 0
          desc = "-- Sum of #{last_year} of #{last_year_acc.path}"
          date = "#{last_year + 1}-#{month_start.to_s.rjust(2, '0')}-01"
          dputs(3) { "Deleting old sums with date #{date.inspect}" }
          Movements.matches_by_desc("^#{desc}$").each { |m|
            dputs(3) { "Testing movement with date #{m.date.to_s.inspect}: #{m.to_json}" }
            if m.date.to_s == date.to_s
              dputs(3) { 'Deleting it' }
              m.delete
            end
          }
          dputs(3) { "Creating movement for the sum of last year: #{last_total}" }
          mov = Movements.create(desc, date, last_total,
                                 last_year_acc_parent, aacc)
          last_year_acc_parent.dump true
          dputs(3) { "Movement is: #{mov.to_json}" }
        end
        aacc.update_total
        dputs(5) { "#{aacc.total} - #{aacc.multiplier}" }
        last_total = aacc.total * aacc.multiplier
      else
        dputs(4) { "Didn't find archived account for #{y}" }
        last_total = 0
      end
      last_year, last_year_acc, last_year_acc_parent = y, aacc, a
    }
  end

  def self.archive(month_start = 1, this_year = nil, only_account = nil)
    if not this_year
      now = Time.now
      this_year = now.year
      now.month < month_start and this_year -= 1
    end

    root = AccountRoot.actual
    if only_account
      root = only_account
    elsif not root
      dputs(0) { 'Error: Root-account not available!' }
      return false
    elsif (root.account_id > 0)
      dputs(0) { "Error: Can't archive with Root is not in root: #{root.account_id.inspect}!" }
      return false
    end

    archive = AccountRoot.archive
    if not archive
      archive = self.create('Archive')
    end

    years_archived = {}
    archive.accounts.each { |a| years_archived[a.name.to_i] = a }

    dputs(2) { 'Got root and archive' }
    # For every account we search the most-used year, so
    # that we can move the account to that archive. This way
    # we omit as many as possible updates for the clients, as
    # every displacement of a movement will have to be updated,
    # while the displacement of an account is much simpler
    root.get_tree_depth { |acc|
      dputs(2) { "Looking at account #{acc.path}" }
      years = search_account(acc, month_start)

      if years.size > 0
        most_used = last_used = this_year
        if acc.accounts.count == 0
          most_used = years.key(years.values.max)
          last_used = years.keys.max
          years.delete most_used
        end
        acc_path = acc.path

        dputs(3) { "most_used: #{most_used} - last_used: #{last_used}" +
            "- acc_path: #{acc_path}" }

        # First move all other movements around
        if years.keys.size > 0
          create_accounts(acc, years, years_archived, this_year)

          move_movements(acc, years, month_start)
        end

        if most_used != this_year
          # Now move account to archive-year of most movements
          parent = archive_parent(acc, years_archived, most_used)
          if double = Accounts.get_by_path("#{parent.get_path}::#{acc.name}")
            dputs(3) { "Account #{acc.path_id} already exists in #{parent.path_id}" }
            # Move all movements
            acc.movements.each { |m|
              dputs(4) { "Moving movement #{m.to_json}" }
              value = m.value
              m.value = 0
              if m.account_src == acc
                m.account_src_id = double
              else
                m.account_dst_id = double
              end
              m.value = value
            }
            # Delete acc
            acc.delete
          else
            dputs(3) { "Moving account #{acc.path_id} to #{parent.path_id}" }
            acc.parent = parent
          end
        end

        # Check whether we need to add the account to the current year
        if (last_used >= this_year - 1) and
            (most_used != this_year)
          dputs(3) { "Adding #{acc_path} to this year with mult #{acc.multiplier}" }
          Accounts.create_path(acc_path, 'Copied from archive', false,
                               acc.multiplier, acc.keep_total)
        end

        if acc.keep_total
          dputs(2) { "Keeping total for #{acc_path}" }
          # And create a trail so that every year contains the previous
          # years worth of "total"
          sum_up_total(acc_path, years_archived, month_start)
          dputs(5) { "acc_path is now #{acc_path}" }
        else
          dputs(2) { "Not keeping for #{acc_path}" }
        end
      else
        dputs(3) { "Empty account #{acc.movements.count} - #{acc.accounts.count}" }
      end

      if acc.accounts.count == 0
        movs = acc.movements
        case movs.count
          when 0
            dputs(3) { "Deleting empty account #{acc.path}" }
            if acc.path != 'Root'
              acc.delete
            else
              dputs(2) { 'Not deleting root!' }
            end
          when 1
            dputs(3) { "Found only one movement for #{acc.path}" }
            if movs.first.desc =~ /^-- Sum of/
              dputs(3) { 'Deleting account which has only a sum' }
              movs.first.delete
              if acc.path != 'Root'
                acc.delete
              else
                dputs(2) { 'Not deleting root!' }
              end
            end
        end
      end
    }
    if DEBUG_LVL >= 3
      self.dump
    end
  end

  def self.dump_raw(mov = false)
    Accounts.search_all.each { |a|
      a.dump(mov)
    }
  end

  def self.dump(mov = false)
    dputs(1) { 'Root-tree is now' }
    AccountRoot.actual.dump_rec(mov)
    if archive = AccountRoot.archive
      dputs(1) { 'Archive-tree is now' }
      archive.dump_rec(mov)
    else
      dputs(1) { 'No archive-tree' }
    end
    AccountRoot.accounts.each { |a|
      dputs(1) { "Root-Account: #{a.inspect}" }
    }
  end

  def init
    root = Accounts.create('Root', 'Initialisation')
    %w( Income Outcome Lending Cash ).each { |a|
      Accounts.create(a, 'Initialisation', root)
    }
    %w( Lending Cash ).each { |a|
      acc = Accounts.match_by_name(a)
      acc.multiplier = -1
      acc.keep_total = true
    }
    Accounts.save
  end

  def load
    super
    if Accounts.search_by_name('Root').count == 0
      dputs(1) { "Didn't find 'Root' in database - creating base" }
      Accounts.init
    end
  end

  def migration_1(a)
    dputs(4) { Accounts.storage[:SQLiteAC].db_class.inspect }
    a.deleted = false
    # As most of the accounts in Cash have -1 and shall be kept, this
    # gives a good first initialisation
    a.keep_total = (a.multiplier == -1.0) || (a.multiplier == -1)
    dputs(4) { "#{a.name}: #{a.deleted.inspect} - #{a.keep_total.inspect}" }
  end

  def migration_2(a)
    a.rev_index = a.id
  end

  def migration_3(m)
    # dp "Migrating #{m.inspect}"
    if m.id == 1 && m.account_id != nil
      dp 'Root-account has parent...'
      m.account_id = 0
      m.name = 'Root'
      m.desc = 'Root'
      m.global_id = Digest::MD5.hexdigest((rand 2**128).to_s).to_s + '-1'
      m.total = 0.0
    end
  end

  def listp_path
    dputs(3) { 'Being called' }
    Accounts.search_all.select { |a| !a.deleted }.collect { |a| [a.id, a.path] }.
        sort { |a, b|
      a[1] <=> b[1]
    }
  end

  def bool_to_s(b)
    (b && b != 'f') ? 'true' : 'false'
  end

  def check_against_db(file)
    # First build
    # in_db - content of 'file' in .to_s format
    # in_local - content available locally in .to_s format
    in_db, diff, in_local = [], [], []
    dputs(3) { 'Searching all accounts' }
    @check_state = 'Collect local'
    @check_progress = 0.0
    in_local = Accounts.search_all_
    progress_step = 1.0 / (in_local.size + 1)
    dputs(3) { "Found #{in_local.size} accounts" }

    @check_state = 'Collect local'
    in_local = in_local.collect { |a|
      @check_progress += progress_step
      a.to_s
    }

    dputs(3) { 'Loading file-db' }
    @check_state = 'Collect file-DB'
    @check_progress = 0.0
    SQLite3::Database.new(file) do |db|
      db.execute('select id, account_id, name, desc, global_id, total, '+
                     'multiplier, "index", rev_index, deleted, keep_total '+
                     'from compta_accounts').sort_by { |a| a[4] }.each do |row|
        #dputs(3) { "Looking at #{row}" }
        @check_progress += progress_step

        _, acc_id_, name_, desc_, gid_, tot_, mult_, _, _, del_, keep_, = row
        parent = if acc_id_
                   acc_id_ == 0 ? '' :
                       db.execute("select * from compta_accounts where id=#{acc_id_}").first[4]
                 else
                   ''
                 end
        in_db.push "#{desc_}\r#{gid_}\t" +
                       "#{sprintf('%.3f', tot_.to_f.round(3))}\t#{name_.to_s}\t"+
                       "#{mult_.to_i.to_s}\t#{parent}" +
                       "\t#{bool_to_s(del_)}" + "\t#{bool_to_s(keep_)}"
      end
    end

    # Now compare what is available only in db and what is available only locally
    dputs(3) { 'Comparing local accounts with file-db accounts' }
    @check_state = 'On one side'
    @check_progress = 0.0
    in_db.delete_if { |a|
      @check_progress += progress_step
      in_local.delete(a)
    }

    # And search for accounts with same global-id but different content
    dputs(3) { 'Seaching mix-ups' }
    @check_state = 'Mixed-up'
    @check_progress = 0.0
    progress_step = 1.0 / (in_db.size + 1)
    (in_db + in_local).sort_by { |a| a.match(/\r(.*?)\t/)[1] }
    in_db.delete_if { |a|
      @check_progress += progress_step
      gid = a.match(/\r(.*?)\t/)[1]
      if c = in_local.find { |b| b =~ /\r#{gid}\t/ }
        diff.push [a, c]
        in_local.delete c
      end
    }

    @check_state = 'Done'
    [in_db, diff, in_local]
  end
end

class AccountRoot

  def self.actual
    self.accounts.find { |a| a.name == 'Root' }
  end

  def self.current
    AccountRoot.actual
  end

  def self.archive
    self.accounts.find { |a| a.name == 'Archive' }
  end

  def self.accounts
    Accounts.matches_by_account_id(0)
  end

  def self.clean
    count_mov, count_acc = 0, 0
    bad_mov, bad_acc = 0, 0
    log_msg 'Account.clean', 'starting to clean up'
    Movements.search_all_.each { |m|
      dputs(4) { "Testing movement #{m.inspect}" }
      if not m or not m.date or not m.desc or not m.value or
          not m.rev_index or not m.account_src or not m.account_dst
        if m and m.desc
          log_msg 'Account.clean', "Bad movement: #{m.inspect}"
        end
        m.delete
        bad_mov += 1
      end
      if m.rev_index
        count_mov = [count_mov, m.rev_index].max
      end
    }
    Accounts.search_all_.each { |a|
      if (a.account_id && (a.account_id > 0)) && (!a.account)
        log_msg 'Account.clean', "Account has unexistent parent: #{a.inspect}"
        a.delete
        bad_acc += 1
      end
      if !(a.account_id || a.deleted)
        log_msg 'Account.clean', "Account has undefined parent: #{a.inspect}"
        a.delete
        bad_acc += 1
      end
      if a.account_id == 0 || a.account_id == nil
        if !((a.name =~ /(Root|Archive)/) || a.deleted)
          log_msg 'Account.clean', 'Account is in root but neither ' +
                                     "'Root' nor 'Archive': #{a.inspect}"
          a.delete
          bad_acc += 1
        end
      end
      if !a.rev_index
        log_msg 'Account.clean', "Didn't find rev_index for #{a.inspect}"
        a.new_index
        bad_acc += 1
      end
      count_acc = [count_acc, a.rev_index].max
    }

    # Check also whether our counters are OK
    u_l = Users.match_by_name('local')
    dputs(1) { "Movements-index: #{count_mov} - #{u_l.movement_index}" }
    dputs(1) { "Accounts-index: #{count_acc} - #{u_l.account_index}" }
    @ul_mov, @ul_acc = u_l.movement_index, u_l.account_index
    if count_mov > u_l.movement_index
      log_msg 'Account.clean', 'Error, there is a bigger movement! Fixing'
      u_l.movement_index = count_mov + 1
    end
    if count_acc > u_l.account_index
      log_msg 'Account.clean', 'Error, there is a bigger account! Fixing'
      u_l.account_index = count_acc + 1
    end
    return [count_mov, bad_mov, count_acc, bad_acc]
  end

  def self.path_id
    return ''
  end

  def self.id
    0
  end

  def self.mult
    1
  end

  def self.keep_total
    false
  end

  def self.multiplier
    1
  end
end

class Account < Entity

  def data_set(f, v)
    if !@proxy.loading
      if !%w( _total _rev_index _global_id ).index(f.to_s)
        dputs(4) { "Updating index for field #{f.inspect} - #{@pre_init} - #{@proxy.loading}: #{v}" }
        new_index
      end
    end
    super(f, v)
  end

  # This gets the tree under that account, breadth-first
  def get_tree(depth = -1)
    yield self, depth
    return if depth == 0
    accounts.sort { |a, b| a.name <=> b.name }.each { |a|
      a.get_tree(depth - 1) { |b| yield b, depth - 1 }
    }
  end

  # This gets the tree under that account, depth-first
  def get_tree_depth
    accounts.sort { |a, b| a.name <=> b.name }.each { |a|
      a.get_tree_depth { |b| yield b }
    }
    yield self
  end

  def get_tree_debug(ind = '')
    yield self
    dputs(1) { "get_tree_ #{ind}#{self.name}" }
    accounts.sort { |a, b| a.name <=> b.name }.each { |a|
      a.get_tree_debug("#{ind} ") { |b| yield b }
    }
  end

  def path(sep = '::', p='', first=true)
    if (acc = self.account)
      return acc.path(sep, p, false) + sep + self.name
    else
      return self.name
    end
  end

  def path_id(sep = '::', p='', first=true)
    (self.account ?
        "#{self.account.path_id(sep, p, false)}#{sep}" : '') +
        "#{self.name}-#{self.id}"
  end

  def get_path(sep = '::', p = '', first = true)
    path(sep, p, first)
  end

  def new_index()
    if !u_l = Users.match_by_name('local')
      dputs(0) { "Oups - user 'local' was not here: #{caller}" }
      u_l = Users.create('local')
    end
    self.rev_index = u_l.account_index
    u_l.account_index += 1
    dputs(3) { "Index for account #{name} is #{rev_index}" }
  end

  def update_total(precision = 3)
    # Recalculate everything.
    dputs(4) { "Calculating total for #{self.path_id} with mult #{self.multiplier}" }
    self.total = (0.0).to_f
    dputs(4) { "Total before update is #{self.total} - #{self.total.class.name}" }
    self.movements.each { |m|
      v = m.get_value(self)
      dputs(5) { "Adding value #{v.inspect} to #{self.total.inspect}" }
      self.total = self.total.to_f + v.to_f
      dputs(5) { "And getting #{self.total.inspect}" }
    }
    self.total = self.total.to_f.round(precision)
    dputs(4) { "Final total is #{self.total} - #{self.total.class.name}" }
  end

  # Sets different new parameters.
  def set_nochildmult(name, desc, parent = nil, multiplier = 1, users = [],
                      keep_total = false)
    self.name, self.desc, self.keep_total = name, desc, keep_total
    parent and self.account_id = parent
    # TODO: implement link between user-table and account-table
    # self.users = users ? users.join(":") : ""
    self.multiplier = multiplier
    self.keep_total = keep_total
    update_total
    self
  end

  def set(name, desc, parent, multiplier = 1, users = [], keep_total = false)
    dputs(3) { "Going to set #{name}-#{parent}-#{multiplier}" }
    set_nochildmult(name, desc, parent, multiplier, users, keep_total)
    # All descendants shall have the same multiplier
    set_child_multiplier_total(multiplier, total)
  end

  # Sort first regarding inverse date (newest first), then description,
  # and finally the value
  def movements(from = nil, to = nil)
    dputs(5) { 'Account::movements' }
    movs = (movements_src + movements_dst)
    if (from != nil and to != nil)
      movs.delete_if { |m|
        (m.date < from || m.date > to)
      }
      dputs(3) { 'Rejected some elements' }
    end
    movs.delete_if { |m| m.value == 0 }
    sorted = movs.sort { |a, b|
      ret = 0
      if a.date and b.date
        ret = a.date.to_s <=> b.date.to_s
      end
      if ret == 0
        ret = a.rev_index <=> b.rev_index
=begin
        if a.desc and b.desc
          ret = a.desc <=> b.desc
        end
        if ret == 0
          if a.value and b.value
            ret = a.value.to_f <=> b.value.to_f
          end
        end
=end
      end
      if ret
        ret * -1
      else
        dputs(0) { "Error: Ret shouldn't be nil... #{self.path}" }
        0
      end
    }
    sorted
  end

  def bool_to_s(b)
    b ? 'true' : 'false'
  end

  def to_s(add_path = false)
    if account || true
      dputs(4) { "Account-desc: #{name.to_s}, #{global_id}, #{account_id.inspect}" }
      "#{desc}\r#{global_id}\t" +
          "#{sprintf('%.3f', total.to_f.round(3))}\t#{name.to_s}\t#{multiplier.to_i.to_s}\t" +
          (account_id ? ((account_id > 0) ? account.global_id.to_s : '') : '') +
          "\t#{bool_to_s(self.deleted)}" + "\t#{bool_to_s(self.keep_total)}" +
          (add_path ? "\t#{path}" : '')
    else
      'nope'
    end
  end

  def is_empty
    size = self.movements.select { |m| m.value.to_f != 0.0 }.size
    dputs(2) { "Account #{self.name} has #{size} non-zero elements" }
    dputs(4) { "Non-zero elements: #{movements.inspect}" }
    if size == 0 and self.accounts.size == 0
      return true
    end
    return false
  end

  # Be sure that all descendants have the same multiplier and keep_total
  def set_child_multiplier_total(m, t)
    dputs(3) { "Setting multiplier from #{name} to #{m} and keep_total to #{t}" }
    self.multiplier = m
    self.keep_total = t
    return if not accounts
    accounts.each { |acc|
      acc.set_child_multiplier_total(m, t)
    }
    self
  end
  
  def accounts
    # Some hand-optimized stuff. This would be written shorter like this:
    # Accounts.matches_by_account_id( self.id )
    # But the code below is 3 times faster for some big data
    ret = []
    Accounts.data.each { |k, v|
      if v[:account_id] == self.id
        ret.push Accounts.get_data_instance(k)
      end
    }
    ret
  end

  # This is the parent account
  def account
    Accounts.match_by_id(self.account_id)
  end

  def account=(a)
    self.account_id = a.class == Account ? a.id : a
  end

  def parent
    account
  end

  def parent=(a)
    self.account = a
  end

  def movements_src
    Movements.matches_by_account_src_id(self.id)
  end

  def movements_dst
    Movements.matches_by_account_dst_id(self.id)
  end

  def multiplier
    _multiplier.to_i
  end

  def delete(force = false)
    if not is_empty && force
      movements_src.each { |m|
        dputs(3) { "Deleting movement #{m.to_json}" }
        m.delete
      }
    end
    if is_empty
      dputs(2) { "Deleting account #{self.name}-#{self.id}" }
      self.account_id = nil
      self.deleted = true
    else
      dputs(1) { "Refusing to delete account #{name}" }
      return false
    end
    return true
  end

  def print_pdf_document(pdf)
    sum = 0
    pdf.font_size 10
    movs = movements.select { |m|
      m.value.abs >= 0.001
    }.sort { |a, b| a.date <=> b.date }
    if movs.length > 0
      header = [['', {:content => "#{path}", :colspan => 2, :align => :left},
                 {:content => "#{id}", :align => :right}],
                %w(Date Description Other # Value Sum).collect { |ch|
                  {:content => ch, :align => :center} }]
      pdf.table(header +
                    movs.collect { |m|
                      other = m.get_other_account(self)
                      value = m.get_value(self)
                      [{:content => m.date.to_s, :align => :center},
                       m.desc,
                       other.name,
                       {:content => "#{other.id}", :align => :right},
                       {:content => "#{Account.total_form(value)}", :align => :right},
                       {:content => "#{Account.total_form(sum += value)}", :align => :right}]
                    }, :header => true, :column_widths => [70, 400, 100, 40, 75, 75])
      pdf.move_down(2.cm)
    end
  end

  def print_pdf(file, recursive = false)
    Prawn::Document.generate(file,
                             :page_size => 'A4',
                             :page_layout => :landscape,
                             :bottom_margin => 2.cm,
                             :top_margin => 2.cm) do |pdf|
      if recursive
        get_tree_depth { |a|
          a.print_pdf_document(pdf)
        }
      else
        print_pdf_document(pdf)
      end
      pdf.repeat(:all, :dynamic => true) do
        pdf.draw_text self.path, :at => [0, -20]
        pdf.draw_text pdf.page_number, :at => [14.85.cm, -20]
      end
    end
  end

  def dump(mov = false)
    t = (self.keep_total ? 'K' : '.') + "#{self.multiplier.to_s.rjust(2, '+')}"
    acc_desc = ["**#{t}**#{self.path_id}#{self.deleted ? ' -- deleted' : ''}"]
    dputs(1) { acc_desc.first }
    acc_desc +
        if mov
          movements.collect { |m|
            m_desc = "     #{m.to_json}"
            dputs(1) { m_desc }
            m_desc
          }
        else
          []
        end
  end

  def dump_rec(mov = false)
    ret = []
    get_tree_depth { |a|
      ret.push a.dump(mov)
    }
    ret.flatten
  end

  def listp_path(depth = -1)
    acc = []
    get_tree(depth) { |a|
      acc.push [a.id, a.path]
    }
    dputs(3) { "Ret is #{acc.inspect}" }
    acc
  end

  def total_form
    Account.total_form(total)
  end

  def self.total_form(v)
    (v.to_f * 1000 + 0.5).floor.to_s.tap do |s|
      :go while s.gsub!(/^([^.]*)(\ d)(?=(\ d { 3 })+)/, "\\1\\2,")
    end
  end

  def get_archives
    if archive = AccountRoot.archive
      archive.accounts.collect { |arch|
        Accounts.get_by_path("#{arch.path}::#{path.sub(/^Root::/, '')}")
      }.select { |a| a }
    end
  end

  def get_archive(year = Date.today.year - 1, month = Date.today.month)
    dputs(0) { 'Error: not implemented yet' }
  end

end
