<!-- 
.. title: Type Tagging in C++
.. slug: type-tagging-in-cxx
.. date: 05/09/2014 12:01:41 AM UTC
.. tags: c++, type tagging, disposable, tech topic
.. link: 
.. description: 
.. type: text
-->

*Type tagging* wraps invocation arguments in objects of a different type to select a
different instance of an overloaded construct and thus a different processing policy for
the argument. This can be done at no cost at runtime and with a reasonably nice syntax. I'll show use cases and demonstrate a sample implementation.

<!-- TEASER_END -->

# Introduction

*Type tagging* is, what I've been calling the technique of wrapping constructor or method
arguments in a shallow wrapper object to select a different instance of an overloaded
construct and thus a different processing policy for the argument.

Here is an example: Assume you want to construct an object of class *SomeThing* from a
vector of *Foo*. A rather typical approach would be:

```C++
vector<Foo> v;
... build vector v;
SomeThing s(v);
```

In the general case, *SomeThing* would just copy data from *v* to
build up its inner initial state. This might not be as efficient as
desired - copying might be expensive. If, in example, `SomeThing` is
in itself using a `vector<Foo>` to store its internal state the
possibility opens up, to use *std::swap* to take over the content of
*v* by __moving__ it into the object, instead of __copying__.  *v*
would be changed by this operation, so this is only possible if the
content of *v* is not needed any more after object construction,
i.e. if *v* was only a helper object. In practice this case occurs
frequently for objects with non trivial inner structure. But it cannot
be the only mode of construction. It depends on the client code using
*SomeThing* if it wants to continue using v. One might want to
construct a series of related objects, reusing the content of *v*:

```C++
... build vector v;
SomeThing s1(v);
... modify vector v;
SomeThing s2(v);

```

Generally I cannot (and should not want) to restrict the user of my
class to one mode of construction (copying vs. moving). Rather I want
to support both modes with sensible defaults following the principle
of least surprise:

*Type tagging* will allow to do that by marking the argument in the
 following way:

```C++
vector<Foo> v;
... build vector v;
SomeThing s( disposable(v) );
```

will tell the constructor that it can move the content of *v* (if it
supports this), whereas

```
vector<Foo> v;
... build vector v;
SomeThing s( v );
```

still copies the content of *v* (which is the safe default). It is
also desirable that, if *SomeThing* doesn't know about about type
tagging conventions, that the copying constructor is used
instead. This is indeed possible as we will see.

The following article presents a sample implementation of type tagging
(that is, the "operator" *disposable*) and explains how it works. I'll
discuss alternatives to the *type tagging* approach at some other
time.

At this point you might already suspect a relationship to *C++ 11*
rvalue references and *std::move* . You're not wrong: One might think
about *rvalue references* as compiler supplied (that is: automatic)
type tagging. I'll elaborate on this in a follow up article. But the
idea I'm going to present here will work even with *C++ 98* which does
no have rvalue references and can be extended to other areas of
application (beyond selecting copying/moving constructors).


# Implementation

## Goals

To summarize: If we write

```C++
SomeThing s( v );
```

we want one thing to happen (namely *v* being copied and not
modified), whereas if we write

```C++
SomeThing s( disposable(v) );
```

we want another thing to happen (namely the content of *v* being
reused for the sake of efficiency, accepting that *v* is being
modified in the process).

This can be effected, of course, by implementing two different
versions of the constructor *SomeThing* which take different Types:

```C++
SomeThing(const Multiples& m) { ... }
```

and

```C++
SomeThing(DisposableRef<Multiples> dm) { ... }
```

(For my implementation example I assume that the parameter passed to
the constructor is an object of class *Multiples*. You'll find the
complete implementation in the [listing]).

The job of `disposable()` is just to wrap a class of type
*DisposableRef<Multiples>* around a `Multiples&` to provide the type
that will make the compiler select the alternate constructor.

## The Wrapper Class

The wrapper class *DisposableRef<Multiples>* is easily defined as a
template:

```C++
template<typename T>
class DisposableRef { 
public:
  inline DisposableRef(T& inner) : inner(inner){ };
  inline T& ref()        { return inner ; }
private:
  T& inner;
};
```

The constructor simply stores the reference, the method
`DisposableRef::ref()` is required to retrieve the reference again
(e.g. in the alternate constructor).  

*Disposable* can be implemented as:

```C++
template<typename T>
inline DisposableRef<T> disposable(T& inner){ 
  return DisposableRef<T>(inner);
}
```

*Disposable* is only a wrapper function to avoid having to specify
the type of the argument all the time. `DisposableRef(m)` does not
work, one would have to write `DisposableRef<Multiples>(m)` which
would be too cumbersome. A template function on the other side can be
invoked without a type argument to the template: `disposable(m)`.


Note,

- that *DisposableRef* has the reference as only member,
- that all the methods are non virtual, and can therefore be inlined,
- that they only pass the reference into the object or return the
  reference from the single member.

This means, there is hope that, with a reasonable compiler, this will
compile to the same code as if the raw pointer is being passed
around. 

*DisposableRef* Construction and `disposable()` ideally could be
removed at compile time, that is: compile to *no-ops*, since they take
an address and return the very same address. Ideally they would only
supply type information that is used at run time to select a different
operation, but the address passed around and the way it is passed
around, should always be the same.

After all, the type is something that exists only in the compiler and
the binary representation of `T&` and `Disposable<T>` is probably the
same.

This has not been demonstrated so far in this article and there is no
guarantee in the standard, but it can be strongly expected. A full
demonstration, though, will have to be subject of another follow up
article.

## Testing

Let's test drive my implementation, First we fill in the
implementation of *SomeThing*:

```C++
class SomeThing {
public:
  SomeThing(const Multiples& m) {
    cout << "Something: Received NON-disposable argument - need to copy" << endl;
    this->m =  m;
  }
  SomeThing(DisposableRef<Multiples> dm) {
    cout << "Something: Received disposable argument - can swap/move." << endl;
    swap(this->m, dm.ref());
  }
private:
  Multiples m;
};
```

Now, if we execute the following statements (assuming an output
operator has been defined for *Multiples*)

```C++
Multiples m(3,7);
cout << m;

SomeThing st2( m );                // 1st call
cout << m;

SomeThing st1( disposable(m) );    // 2nd call
cout << m;
```

then we get the following:

    Multiples @ 0xbf93b39c counting 3:
     7 14 21.
    Something: Received NON-disposable argument - need to copy
    Multiples @ 0xbf93b39c counting 3:
     7 14 21.
    Something: Received disposable argument - can swap/move.
    Multiples @ 0xbf93b39c counting 0:
    .
    
This is exactly as desired: The first call selects the first
constructor which copies the data from the argument, leaving the
argument unmodified. The second call selects the second constructor
which swaps the internal state of the argument into the object
instead.
 
## More Motivation

There is one aspect noteworthy in the method demonstrated so far: The
decision if the argument can be destroyed, is left to the caller
(instead of the designer of the class *SomeThing*). This is as it
should be: The class designer cannot decide which method (*swap* or
*copy*) is best for building the internal class state. Only providing
a "copying" constructor would close the door on any optimization in
this regard. Only providing a "swapping" constructor would lead to
undue surprises when invoked as *SomeThing(m)*.

The effect I'm achieving so far with the demonstrated implementation
is

- invoking the copying constructor by default and
- invoking the swapping constructor only if this is marked so at the
  place of invocation,

This is exactly the right way to go.

There is one issue left, though: Exactly because the user of
*SomeThing* rather than the designer is providing the policy
information implicit in the markup with `disposable()`, he would have
to check for every class, if it provides a swapping
constructor. Imagine a class *SomeThingElse* which does only provide
the copying constructor as given above. `SomeThingElse se1(
disposable(m) )` would end in an error message by the compiler:

```
example1_type-tagging.cc:85: error: no matching function for call to ‘SomeThingElse::SomeThingElse(DisposableRef<Multiples>)’
example1_type-tagging.cc:62: note: candidates are: SomeThingElse::SomeThingElse(const Multiples&)
example1_type-tagging.cc:60: note:                 SomeThingElse::SomeThingElse(const SomeThingElse&)
```

But in the end it would be very much desirable to be able to use
*disposable()* even in cases where there is no swapping constructor,
and profit from a swapping constructor if one is introduced in perhaps
a later version of *SomeThingElse*.

Fortunately this feature is easily added to *DisposableRef* as
demonstrated in the next section, so a user of a class can always
write `SomeThingElse se1( disposable(m) )` without having to know if a
swapping constructor exists. This way he can use *disposable()* just
to mark up, that he is not interested in the content of the argument
*m* any more and that construction *might* be optimized by swapping
out state from *m*.

The question if this is *actually* done is now removed from
implementing the data flow. It can instead become a part of later
optimization process or part of the dialog between the class designer
and somebody (maybe even some third party) identifying performance
bottle necks and optimizing the application. The data processing
logic, at that later point is not affected and the code at the point
of invocation needs not to be changed.

Maybe even more important: The call to *disposable()* could then be
generated by a template without regard to the constructors provided by
some template class argument.

## Fallbacks

The desired fallback can be implemented by adding a conversion
operator from `DisposableRef<T>` to `T&` to `DisposableRef<T>`:

```C++
template<typename T>
class DisposableRef { 
public:
  inline operator T&() { return inner ; }
  ...
};
```

Now in the following code fragment 

```C++
Multiples m2(5,5);
cout << m2;

SomeThingElse se2( m2 );              // Call 1
SomeThingElse se1( disposable(m2) );  // Call 2

cout << m2;
```

*Call 2* will compile, but will select the same (and only) constructor
 as *call 1*:

    Multiples @ 0xbfca62f8 counting 5:
     5 10 15 20 25.
    SomethingElse: Treating as NON-disposable argument - need to copy
    SomethingElse: Treating as NON-disposable argument - need to copy
    Multiples @ 0xbfca62f8 counting 5:
     5 10 15 20 25.
 
Xou can see: The argument *m2* will not be modified.

Note, that constructor selection for *SomeThing* still works as
demonstrated above, since, when resolving the constructor overloading,
the compiler will

- first look for a constructor with exactly the type signature of the
  arguments at the invocation,
- and only then look for suitable conversions which would allow an
  alternative constructor to be invoked.

Since it finds `SomeThing(DisposableRef<Multiples> dm)` first, the
possibility of conversion will never be considered,

# Coda

What I've demonstrated so far is a - in my opinion rather nice -
syntax, to direct the system to handle an argument to a constructor in
a way different from the default. But I've intentionally omitted to
delve into some points:

- What are the alternatives to using type tagging as demonstrated?
  What about using a flag as a parameter? What about using a special
  builder syntax instead of passing a complex data structure? What
  about using *const* to control copying vs. swapping? What about
  *std::copy*?

- I've only asserted that I consider it rather probable that type
  tagging comes without extra runtime cost. This still needs to be
  demonstrated.

- *std::move* looks rather related to type tagging. Indeed it is the
  *same idea -- rvalue references* are compiler supplied type tagging
  *(if you, like me, insist to understand rvalue references* based on
  *the type tagging idea) and *std:move* like *disposable* just
  *converts the type at compile time.

- Type tagging can be used for more than selecting different
  constructors.

All these points will be subject of further articles in this mini
series.

# Resources

- Demo implementation: [listings/ type-tagging-in-cxx/ example1_type-tagging.cc][listing]

  [listing]: /listings/type-tagging-in-cxx/example1_type-tagging.cc.html




