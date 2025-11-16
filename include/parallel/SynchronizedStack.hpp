#ifndef SYNCHRONIZEDSTACK_HPP
#define SYNCHRONIZEDSTACK_HPP

#include <omp.h>
#include <stack>
#include <memory>
#include "Stack.hpp"

namespace vflib {

template<typename T>
class SynchronizedStack : public Stack<T> {
private:
	std::stack<std::shared_ptr<T>> stack;

public:
	void push(T const& data) {
		#pragma omp critical(sync_stack_push)
		{
			stack.push(std::make_shared<T>(data));
		}
	}

	size_t size() {
		size_t result;
		#pragma omp critical(sync_stack_size)
		{
			result = stack.size();
		}
		return result;
	}

	std::shared_ptr<T> pop() {
		std::shared_ptr<T> res;
		#pragma omp critical(sync_stack_pop)
		{
			if(stack.size()) {
				res = stack.top();
				stack.pop();
			}
		}
		return res;
	}
};

}

#endif