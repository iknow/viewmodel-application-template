{ stdenv, lib, makeWrapper, ffmpeg-headless, cloudflare-sandbox, jemalloc, sandbox-dlopen-stub, sandbox-gmtime-stub }:

stdenv.mkDerivation {
  name = "sandboxed-ffmpeg";

  nativeBuildInputs = [makeWrapper];
  dontUnpack = true;

  installPhase = let
    requiredSyscalls = [
      "read" "write" "ioctl" "rt_sigaction" "brk" "futex" "set_robust_list" "mmap"
      "mprotect" "madvise" "munmap" "rt_sigprocmask" "getrusage"
      "sched_getaffinity" "exit" "exit_group" "rseq" "clone3" "clone"
      "clock_nanosleep" "getpriority" "setpriority" "close" "dup" "fcntl" "prctl"
    ];

    ffprobeRequiredSyscalls = requiredSyscalls ++ ["fstat" "lseek"];
  in ''
    mkdir -p $out/bin

    makeWrapper "${ffmpeg-headless}/bin/ffmpeg" "$out/bin/ffmpeg" \
       --set LD_PRELOAD "${cloudflare-sandbox}/lib/libsandbox.so ${jemalloc}/lib/libjemalloc.so ${sandbox-dlopen-stub}/lib/dlopen_stub.so" \
       --set SECCOMP_SYSCALL_ALLOW "${lib.concatStringsSep ":" requiredSyscalls}"

    makeWrapper "${ffmpeg-headless}/bin/ffprobe" "$out/bin/ffprobe" \
       --set LD_PRELOAD "${cloudflare-sandbox}/lib/libsandbox.so ${jemalloc}/lib/libjemalloc.so ${sandbox-dlopen-stub}/lib/dlopen_stub.so ${sandbox-gmtime-stub}/lib/gmtime_stub.so" \
       --set SECCOMP_SYSCALL_ALLOW "${lib.concatStringsSep ":" ffprobeRequiredSyscalls}"
  '';

  meta = {
    platforms = lib.platforms.linux;
  };
}
