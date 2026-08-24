#pragma once
#include <vector>
#include <cstddef>
#include <utility>
#include <new>

namespace HFT {

template <typename T, std::size_t BlockSize = 16384>
class MemoryPool {
private:
    union Node {
        T element;
        Node* next;

        Node() {}
        ~Node() {}
    };

    struct Arena {
        alignas(64) Node storage[BlockSize];
    };

    std::vector<Arena*> arenas;
    Node* freeList = nullptr;

    void allocateBlock() {
        Arena* arena = new Arena();
        arenas.push_back(arena);
        for (std::size_t i = 0; i < BlockSize; ++i) {
            arena->storage[i].next = freeList;
            freeList = &arena->storage[i];
        }
    }

public:
    MemoryPool() {
        allocateBlock();
    }

    ~MemoryPool() {
        for (auto arena : arenas) {
            delete arena;
        }
    }

    MemoryPool(const MemoryPool&) = delete;
    MemoryPool& operator=(const MemoryPool&) = delete;

    template <typename... Args>
    T* allocate(Args&&... args) {
        if (__builtin_expect(!freeList, 0)) {
            allocateBlock();
        }
        Node* node = freeList;
        freeList = freeList->next;
        return new (&node->element) T(std::forward<Args>(args)...);
    }

    void deallocate(T* p) {
        if (__builtin_expect(!p, 0)) return;
        p->~T();
        Node* node = reinterpret_cast<Node*>(p);
        node->next = freeList;
        freeList = node;
    }
};

} // namespace HFT
