// Implements a width-aware direct-memory HTIF transport over aligned word chunks.
#include "direct_mem_htif.h"

#include <stdexcept>

namespace rhdl::fesvr {
namespace {

constexpr std::size_t kWordBytes = sizeof(std::uint32_t);

std::uint32_t load_little_endian_word(const void* source) {
  const auto* bytes = static_cast<const std::uint8_t*>(source);
  return static_cast<std::uint32_t>(bytes[0]) |
         (static_cast<std::uint32_t>(bytes[1]) << 8) |
         (static_cast<std::uint32_t>(bytes[2]) << 16) |
         (static_cast<std::uint32_t>(bytes[3]) << 24);
}

void store_little_endian_word(std::uint32_t word, void* destination) {
  auto* bytes = static_cast<std::uint8_t*>(destination);
  bytes[0] = static_cast<std::uint8_t>(word);
  bytes[1] = static_cast<std::uint8_t>(word >> 8);
  bytes[2] = static_cast<std::uint8_t>(word >> 16);
  bytes[3] = static_cast<std::uint8_t>(word >> 24);
}

void require_word_transfer(addr_t address, std::size_t length) {
  if (length != kWordBytes || (address & (kWordBytes - 1)) != 0) {
    throw std::runtime_error("direct-memory HTIF requires aligned four-byte transfers");
  }
}

}  // namespace

DirectMemoryHtif::DirectMemoryHtif(int argc, char** argv, int expected_xlen)
    : htif_t(argc, argv) {
  if (expected_xlen != 32 && expected_xlen != 64) {
    throw std::invalid_argument("direct-memory HTIF target XLEN must be 32 or 64");
  }
  set_expected_xlen(expected_xlen);
  target_context_ = context_t::current();
  host_context_.init(host_thread_main, this);
}

void DirectMemoryHtif::host_thread_main(void* argument) {
  auto* transport = static_cast<DirectMemoryHtif*>(argument);
  transport->run();
  while (true) {
    transport->switch_to_target();
  }
}

void DirectMemoryHtif::tick(bool request_ready,
                            bool response_valid,
                            std::uint32_t response_data,
                            bool start_ready) {
  if (request_pending_) {
    if (!request_exposed_) {
      request_exposed_ = true;
    } else if (!request_accepted_ && request_ready) {
      request_accepted_ = true;
    }

    if (request_accepted_ && response_valid) {
      response_data_ = response_data;
      request_pending_ = false;
      request_exposed_ = false;
      request_accepted_ = false;
    }
  }

  if (start_pending_) {
    if (!start_exposed_) {
      start_exposed_ = true;
    } else if (start_ready) {
      start_pending_ = false;
      start_exposed_ = false;
    }
  }

  host_context_.switch_to();
}

bool DirectMemoryHtif::request_valid() const {
  return request_pending_ && request_exposed_ && !request_accepted_;
}

const DirectMemoryRequest& DirectMemoryHtif::request() const {
  return request_;
}

bool DirectMemoryHtif::response_ready() const {
  return request_pending_ && request_accepted_;
}

bool DirectMemoryHtif::start_valid() const {
  return start_pending_ && start_exposed_;
}

std::uint64_t DirectMemoryHtif::start_entry() const {
  return start_entry_;
}

std::uint32_t DirectMemoryHtif::exit_word() {
  return done() ? (static_cast<std::uint32_t>(exit_code()) << 1) | 1 : 0;
}

void DirectMemoryHtif::reset() {
  start_entry_ = get_entry_point();
  start_pending_ = true;
  start_exposed_ = false;
  while (start_pending_) {
    switch_to_target();
  }
}

void DirectMemoryHtif::read_chunk(addr_t address,
                                  std::size_t length,
                                  void* destination) {
  require_word_transfer(address, length);
  store_little_endian_word(transact(false, address, 0), destination);
}

void DirectMemoryHtif::write_chunk(addr_t address,
                                   std::size_t length,
                                   const void* source) {
  require_word_transfer(address, length);
  transact(true, address, load_little_endian_word(source));
}

std::size_t DirectMemoryHtif::chunk_align() {
  return kWordBytes;
}

std::size_t DirectMemoryHtif::chunk_max_size() {
  return kWordBytes;
}

void DirectMemoryHtif::idle() {
  switch_to_target();
}

std::uint32_t DirectMemoryHtif::transact(bool write,
                                         addr_t address,
                                         std::uint32_t data) {
  if (request_pending_) {
    throw std::logic_error("direct-memory HTIF permits only one outstanding request");
  }

  request_ = DirectMemoryRequest{
      .write = write,
      .address = address,
      .data = data,
  };
  request_pending_ = true;
  request_exposed_ = false;
  request_accepted_ = false;

  while (request_pending_) {
    switch_to_target();
  }
  return response_data_;
}

void DirectMemoryHtif::switch_to_target() {
  target_context_->switch_to();
}

}  // namespace rhdl::fesvr
