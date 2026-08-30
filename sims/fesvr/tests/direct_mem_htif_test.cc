// Drives the direct-memory transport through ELF loading, startup, and a passing HTIF exit.
#include "direct_mem_htif.h"

#include <cstdint>
#include <cstdlib>
#include <iostream>
#include <stdexcept>
#include <string>
#include <unordered_map>

namespace {

constexpr std::uint64_t kEntryAddress = 0x0000000180000000ULL;
constexpr std::uint64_t kTohostAddress = kEntryAddress + 0x1000;

[[noreturn]] void fail(const std::string& message) {
  throw std::runtime_error(message);
}

}  // namespace

int main(int argc, char** argv) {
  if (argc != 2) {
    std::cerr << "usage: " << argv[0] << " PAYLOAD.ELF\n";
    return 2;
  }

  char program_name[] = "direct_mem_htif_test";
  char* htif_arguments[] = {program_name, argv[1]};
  auto* transport = new rhdl::fesvr::DirectMemoryHtif(2, htif_arguments, 64);

  std::unordered_map<std::uint64_t, std::uint32_t> memory;
  bool response_valid = false;
  std::uint32_t response_data = 0;
  bool response_pending = false;
  std::size_t response_delay = 0;
  bool saw_read = false;
  bool saw_write = false;
  bool saw_start = false;
  bool request_stalled = false;
  rhdl::fesvr::DirectMemoryRequest stalled_request = {};
  bool start_stalled = false;
  std::uint64_t stalled_entry = 0;

  for (std::size_t cycle = 0; cycle < 100000; ++cycle) {
    const bool request_valid = transport->request_valid();
    const auto request = transport->request();
    const bool response_ready = transport->response_ready();
    const bool start_valid = transport->start_valid();
    const std::uint64_t start_entry = transport->start_entry();
    const bool request_ready = !request_valid || request_stalled;
    const bool start_ready = !start_valid || start_stalled;

    if (response_pending && response_delay != 0) {
      --response_delay;
    }
    response_valid = response_pending && response_delay == 0;

    if (request_valid && !request_ready) {
      if (request_stalled &&
          (request.write != stalled_request.write ||
           request.address != stalled_request.address || request.data != stalled_request.data)) {
        fail("memory request changed while backpressured");
      }
      stalled_request = request;
      request_stalled = true;
    }

    if (start_valid && !start_ready) {
      if (start_stalled && start_entry != stalled_entry) {
        fail("startup entry point changed while backpressured");
      }
      stalled_entry = start_entry;
      start_stalled = true;
    }

    transport->tick(request_ready, response_valid, response_data, start_ready);

    if (response_valid && response_ready) {
      response_pending = false;
    }

    if (request_valid && request_ready) {
      if (request_stalled &&
          (request.write != stalled_request.write ||
           request.address != stalled_request.address || request.data != stalled_request.data)) {
        fail("accepted memory request differs from its stalled value");
      }
      request_stalled = false;
      if (request.write) {
        memory[request.address] = request.data;
        response_data = 0;
        saw_write = true;
      } else {
        const auto found = memory.find(request.address);
        response_data = found == memory.end() ? 0 : found->second;
        saw_read = true;
      }
      response_pending = true;
      response_delay = 2;
    }

    if (start_valid && start_ready) {
      if (start_stalled && start_entry != stalled_entry) {
        fail("accepted startup entry differs from its stalled value");
      }
      start_stalled = false;
      if (start_entry != kEntryAddress) {
        fail("FESVR reported an unexpected ELF entry point");
      }
      saw_start = true;
      memory[kTohostAddress] = 1;
    }

    if (transport->exit_word() != 0) {
      if (transport->exit_word() != 1) {
        fail("FESVR reported a nonzero target exit code");
      }
      if (!saw_read || !saw_write || !saw_start) {
        fail("transport did not exercise reads, writes, and startup");
      }
      if (memory.find(kEntryAddress) == memory.end()) {
        fail("FESVR did not load the payload at its linked address");
      }
      std::cout << "direct-memory FESVR transport test passed\n";
      return 0;
    }
  }

  std::cerr << "direct-memory FESVR transport timed out\n";
  return 1;
}
