#pragma once
#include <atomic>
#include <cstddef>

namespace HFT {

template <typename T, std::size_t Capacity = 131072>
class RingBuffer {
private:
    alignas(64) T buffer[Capacity];
    alignas(64) std::atomic<std::size_t> writeIndex{0};
    alignas(64) std::atomic<std::size_t> readIndex{0};

public:
    RingBuffer() = default;
    ~RingBuffer() = default;

    RingBuffer(const RingBuffer&) = delete;
    RingBuffer& operator=(const RingBuffer&) = delete;

    bool enqueue(const T& item) {
        const std::size_t currentWrite = writeIndex.load(std::memory_order_relaxed);
        const std::size_t currentRead = readIndex.load(std::memory_order_acquire);

        if (currentWrite - currentRead == Capacity) {
            return false; // Queue is full
        }

        buffer[currentWrite % Capacity] = item;
        writeIndex.store(currentWrite + 1, std::memory_order_release);
        return true;
    }

    bool dequeue(T& item) {
        const std::size_t currentRead = readIndex.load(std::memory_order_relaxed);
        const std::size_t currentWrite = writeIndex.load(std::memory_order_acquire);

        if (currentRead == currentWrite) {
            return false; // Queue is empty
        }

        item = buffer[currentRead % Capacity];
        readIndex.store(currentRead + 1, std::memory_order_release);
        return true;
    }

    bool empty() const {
        return readIndex.load(std::memory_order_relaxed) == writeIndex.load(std::memory_order_relaxed);
    }

    std::size_t size() const {
        std::size_t write = writeIndex.load(std::memory_order_relaxed);
        std::size_t read = readIndex.load(std::memory_order_relaxed);
        return (write >= read) ? (write - read) : 0;
    }
};

} // namespace HFT
