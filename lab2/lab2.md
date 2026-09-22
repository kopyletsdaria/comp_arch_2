# ЛАБОРАТОРНА РОБОТА №2

**Тема:** «Розроблення MakeFile та CMake файлів»

**Виконала:** студентка групи ІО-44 Копилець Дар'я (Номер у списку: 8)  

**Перевірив:** Каплунов А.В.

---

## Файли проекту:

calculator.h
```bash
#ifndef CALCULATOR_H
#define CALCULATOR_H
class Calculator
{
	public:
		int Add (double, double);
		int Sub (double, double);
};
#endif//CALCULATOR_H
```

calculator.cpp

```bash
#include "calculator.h"

int Calculator::Add (double a, double b)
{
	return a + b + 0.5;
}

int Calculator::Sub (double a, double b)
{
	return Add (a, -b);
}
```
main.cpp

```bash
#include <iostream>
#include "calculator.h"
using namespace std;
int main() {
    Calculator calc;
 cout << "Add(10.5, 2.3) = " << calc.Add(10.5, 2.3) << endl;
 cout << "Sub(10.5, 2.3) = " << calc.Sub(10.5, 2.3) << endl;
    return 0;
}
```

Makefile.txt

```bash
CXX = g++
CXXFLAGS = -std=c++11 -Wall
TARGET = calculator_app
LIB = libcalculator.a
SRC_MAIN = main.cpp
SRC_LIB = calculator.cpp
OBJ_MAIN = main.o
OBJ_LIB = calculator.o

all: $(TARGET)

$(TARGET): $(OBJ_MAIN) $(LIB)
	$(CXX) $(CXXFLAGS) -o $(TARGET) $(OBJ_MAIN) -L. -lcalculator

$(LIB): $(OBJ_LIB)
	ar rcs $(LIB) $(OBJ_LIB)

$(OBJ_LIB): $(SRC_LIB) calculator.h
	$(CXX) $(CXXFLAGS) -c $(SRC_LIB) -o $(OBJ_LIB)

$(OBJ_MAIN): $(SRC_MAIN) calculator.h
	$(CXX) $(CXXFLAGS) -c $(SRC_MAIN) -o $(OBJ_MAIN)

clean:
	rm -f $(TARGET) $(LIB) $(OBJ_MAIN) $(OBJ_LIB)

.PHONY: all clean
```

CMakeLists.txt

```bash
cmake_minimum_required(VERSION 3.10)
project(CalculatorProject)
set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED True)
add_library(calculator STATIC calculator.cpp)
add_executable(calculator_app main.cpp)
target_link_libraries(calculator_app PRIVATE calculator)
```

## Демонстрація збірки:

<img width="519" height="611" alt="image" src="https://github.com/user-attachments/assets/eb87c964-0c3c-4fa2-b9d3-d441918bd549" />

<img width="522" height="711" alt="image" src="https://github.com/user-attachments/assets/109424b2-87f6-4b48-b194-4cb6a4bf83db" />

## Висновки:

Під час виконання роботи було створено файл Makefile із реалізацією цілі clean для очищення проєктних файлів, а також опановано написання CMakeLists.txt для автоматичного створення бібліотеки та виконуваного файлу. Крім того, набуто практичних навичок генерації сценаріїв збірки за допомогою системи Ninja. Отримані знання дозволили налаштувати та контролювати процес побудови й компіляції програмного забезпечення на мові C++.







