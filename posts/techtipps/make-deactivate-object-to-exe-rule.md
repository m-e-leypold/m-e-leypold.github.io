<!-- 
.. title:       Better deactivate the Linking Rule %: %.o in Makefiles
.. date:       	2013/09/04 12:00:00
.. tags:        blog, techtip, make, en 
.. link:	
.. description: 
.. type: text
-->

<!--
.. excerpt:     The built-in rules of 'make' allow two different paths to build executables from C++
            sources. I recommend to deactivate the rule to link executables from objects
            in your Makefile in order to avoid unwelcome surprise"
-->


Make has built-in rules to translate from C and C++ source to object files, to link object
files to executables, but also a rule to compile from C and C++ source directly into an
executable:

    %.o: %.c:  $(CC)  -c $(CPPFLAGS) $(CFLAGS)
    %.o: %.cc: $(CXX) -c $(CPPFLAGS) $(CXXFLAGS)
    %:   %.o:  $(CC) $(LDFLAGS) N.o $(LOADLIBES) $(LDLIBS)

(This is what the *Gnu Make Manual* documents). In more complex makefiles it's not always
evident, which path of translation will be chosen. It might be either of

    foo.cc --> foo.o --> foo
    foo.cc --> foo

With C source this is not a problem, but with C++ it is: One [should not use the C
compiler to link C++ programs][c++-faq-mixing]. There is more than one way to fix this
problem, but I recommend (for reasons given below) to deactivate the built-in *'%: %.o'*
rule, like this:

    %: %.o # deactivate built-in rule

<!-- TEASER_END -->

# Explanations
## The Problem
### What happened to me
Empirically what I found, was the following. I had one (only one!) C++ source file in a
directory. When calling make without a makefile, what I got was direct translation from
source to executable (using *c++* or *g++* as compiler).

    foo.cc --> foo
    
When using a make file that *did not override* those rules, I got

    foo.cc --> foo.o --> foo
    
The linking was done with *cc* which gives errors since *libstdc++* will not be linked in.
To me it was (and is) not obvious why the other translation path was chosen in the latter
case. I might had to do with the fact, that explicit dependencies (in this case: *foo.o:
foo.c*) were give in the Makefile. I didn't bother to find out the exact reason for the
observed behaviour. At the moment it is sufficient, that the reason is *not obvious* to
make it into something that needs fixing. Behaviour with non obvious causes is a
maintenance nightmare ...

### The Symptoms

Errors like the following occur, when linking with *cc*:

    h1.o: In function `Needle::populate(int)':
    h1.cc:(.text+0x33): undefined reference to `operator new(unsigned int)'
    h1.o: In function `Needle::push(Disk*)':
    h1.cc:(.text+0xcf): undefined reference to `std::cerr'
    h1.cc:(.text+0xd4): undefined reference to `std::basic_ostream<char, std::char_traits<char> >& std::operator<< <std::char_traits<char> >(std::basic_ostream<char, std::char_traits<char> >&, char const*)'

... and so on (mostly I'm quoting them here for the search engine to find). This is, of
course, because *cc* does not link in the standard C++ library, so there is none of the
runtime available. One could try to specify the C++ runtime library in the libraries list
(this works in my case), but the problem with that approach is that *only* the C++
compiler will know best, which libraries to pick up for a proper C++ runtime environment.
Next time or some time in the future - with another compiler version - it might be another
additional library missing... - e.g. nobody and nothing guarantees AFIACS that *libstdc++*
also contains the compiler runtime support procedures.

So - one is supposed to leave the linking of C++ programs to the C++ compiler and not to
the C compiler (and not to ld either). Regarding this, I find
[the C++ FAQ on my side][c++-faq-mixing].


### Removing the Built-in Rule

Removing the built-in rule with

    %: %.o: # deactivate built-in rule
    
has the following advantages:

- It removes the ambiguity mentioned above regarding the canonical translation path. The
  ambiguity is a nuisance anyway and difficult to recognize if a user has only superficial
  knowledge about make.  
- It makes linking dependent on a language specific rule.
- And of course it fixes the problem under consideration by using the C++ compiler to
  link.

### A (small) Disadvantage 

There is also a small disadvantage of the proposed solution: You will never see an object
file corresponding to the main module of your program. Even if you create one explicitly,
e.g. for testing purposes with

    make foo.o CXXFLAGS="-O0 -g"
    
it won't be used when building *foo*. If you need this, I suggest to introduce
a new suffix for object files stemming from C++ sources:

    %.oo: %.cc: ; ... rule to translate from C++ source to object files ...
    %: %.oo:    ; ... rule to link C++ programs ...    
    
and also deactivate the built-in rule that allows to create object files with *.o*-ending
from C++ source.

    %.o: %.cc: # deactivate built-in rule    

## Other File Suffices

Note that *make* also supports *cpp* as suffix for C++ source files. If you have file
ending in *cpp* in your project, you might have to substitute *.cc* by *.cpp* or duplicate
the rules with *.cpp* instead of *.cc*.

## Alternative Solutions

Here are some other fixes for the same problem that in my opinion do not work as well:

- **LOADLIBES=-lstdc++**: One could just add *LOADLIBES=-lstdc++* to the make arguments or
  in the make file and the program would be linked properly. *Disadvantage*: As explained
  above, the list of libraries to add might change with the compiler.

- **CC=c++**: One could try to set *CC=c++*, thus linking C programs with the C++
  compiler. This should work with most tool chains. *Disadvantage*: You might want to link
  C++ and C code differently (to be specified as *CXXFLAGS* and *CFLAGS*). And it doesn't
  resolve the ambiguity regarding the translation path. Personally I'm bothered by
  indeterministic build processes, but YMMV.
  
  [c++-faq-mixing]: http://www.parashift.com/c++-faq/overview-mixing-langs.html

## Note

I've resisted the temptation to title this post *'%: %.o' considered harmful*. There are -
IMHO - to much opinion pieces floating around in the Internet which are titled like
*Something considered harmful* without any sufficient reason or depth of thought.

Which brings me to recognition of the fact that the insight in this post is mostly
trivial: The post is too long for this and has taken me entirely too much time to write up
(while my cat has been harassing me). I can already anticipate that this text will not
make it in the printed volume *Best of Glitzersachen* ;-).

<!-- Local Variables: -->
<!-- mode: markdown -->
<!-- End: -->

<!--  LocalWords:  YMMV behaviour Glitzersachen
 -->
