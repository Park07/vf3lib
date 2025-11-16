#ifndef LOCKFREESTACK_HPP
#define LOCKFREESTACK_HPP

#include <omp.h>
#include <memory>
#include <stack>
#include "Stack.hpp"

namespace vflib {

// OpenMP version - uses critical sections but with finer-grained locking
template<typename T>
class LockFreeStack : public Stack<T> {
private:
	std::stack<std::shared_ptr<T>> data_stack;
	std::stack<std::shared_ptr<T>> free_stack;
	size_t count;

public:
	LockFreeStack() : count(0) {}

	~LockFreeStack() {}

	size_t size() {
		size_t result;
		#pragma omp atomic read
		result = count;
		return result;
	}

	void push(T const& data) {
		std::shared_ptr<T> node_ptr;

		// Try to reuse from free stack
		#pragma omp critical(free_stack_access)
		{
			if (!free_stack.empty()) {
				node_ptr = free_stack.top();
				free_stack.pop();
				*node_ptr = data;
			} else {
				node_ptr = std::make_shared<T>(data);
			}
		}

		#pragma omp critical(data_stack_access)
		{
			data_stack.push(node_ptr);
		}

		#pragma omp atomic
		count++;
	}

	std::shared_ptr<T> pop() {
		std::shared_ptr<T> res;

		#pragma omp critical(data_stack_access)
		{
			if (!data_stack.empty()) {
				res = data_stack.top();
				data_stack.pop();
			}
		}

		if (res) {
			#pragma omp atomic
			count--;

			// Return to free stack for reuse
			#pragma omp critical(free_stack_access)
			{
				free_stack.push(res);
			}
		}

		return res;
	}
};

}

#endif