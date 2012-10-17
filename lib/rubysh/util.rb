require 'set'

module Rubysh
  module Util
    def self.to_fileno(file)
      if file.respond_to?(:fileno)
        file.fileno
      else
        file
      end
    end

    # Leaks memory (needed to avoid Ruby 1.8's IO autoclose behavior),
    # and so you should only use it right before execing.
    def self.io_without_autoclose(fd_num)
      fd_num = to_fileno(fd_num)
      io = IO.new(fd_num)
      hold(io)
      io
    end

    # Should really just shell out to dup2, but looks like we'd need a
    # C extension to do so. The concurrency story here is a bit off,
    # and this probably doesn't copy over all FD state
    # properly. Should be fine for now.
    def self.dup2(fildes, fildes2)
      original = io_without_autoclose(fildes)

      begin
        copy = io_without_autoclose(fildes2)
      rescue Errno::EBADF
      else
        copy.close
      end

      # For some reason, Ruby 1.9 doesn't seem to let you close
      # stdout/sterr. So if we didn't manage to close it above, then
      # just use reopen. We could get rid of the close attempt above,
      # but I'd rather leave this code as close to doing the same
      # thing everywhere as possible.
      begin
        copy = io_without_autoclose(fildes2)
      rescue Errno::EBADF
        res = original.fcntl(Fcntl::F_DUPFD, fildes2)
        Rubysh.assert(res == fildes2, "Tried to open #{fildes2} but ended up with #{res} instead", true)
      else
        copy.reopen(original)
      end
    end

    def self.set_cloexec(file, enable=true)
      file = io_without_autoclose(file) unless file.kind_of?(IO)
      value = enable ? Fcntl::FD_CLOEXEC : 0
      file.fcntl(Fcntl::F_SETFD, value)
    end

    private

    @references = []
    def self.hold(*references)
      # Needed for Ruby 1.8, where we can't set IO objects to not
      # close the underlying FD on destruction
      @references += references
    end
  end
end
