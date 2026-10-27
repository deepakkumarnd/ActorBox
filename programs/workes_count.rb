p RUBY_ENGINE

if RUBY_ENGINE == "spinel"
  module SysInfo
    ffi_source <<~C
      #include <unistd.h>
      long sysinfo_online_cpus(void) {
        long c = sysconf(_SC_NPROCESSORS_ONLN);
        return c < 1 ? 1 : c;
      }
    C
    ffi_func :sysinfo_online_cpus, [], :long
  end

  def online_cores
    SysInfo.sysinfo_online_cpus
  end
else
  require 'etc'
  def online_cores
    Etc.nprocessors
  end
end

# Same logic as sp_worker_count() in spinel's lib/sp_sched.c: SPINEL_WORKERS
# wins when set (even above the core count), clamped to 1..254.
def worker_count
  env = ENV["SPINEL_WORKERS"]
  n = (env && !env.empty?) ? env.to_i : online_cores
  n = 1 if n < 1
  n = 254 if n > 254
  n
end

puts "Online cores: #{online_cores}"
puts "Workers: #{worker_count}"
