---
title: Guava Collection Zero To Hero Part Two
date: 2015-10-06 00:00:00 Z
layout: post
---

第二部分主要展示Guava Collection的使用，从实际用例出发。

##Guava Collection Use Case
在了解了Guava的Function和Predicate后，可以开始使用了。这篇文章里面不是文档的堆积，而是一些具体的使用场景，这些场景仅仅是我遇到的，觉得在一定程度上简化了操作，美化了代码的，希望对读者有所启发，开发自己的Best Practice。

###测试用数据

测试使用一个自定义的数据结构，如下：
<pre><code class="Java">public class Node {
    private Integer id;
    private String title;
    private List&#60;Integer&#62; items;
}</code></code></pre>


###1. 使用transform做抽取

很多时候我们手中会拿到一组复杂的模型，不论是从数据库还是从别人的什么接口。但是真正在我们的逻辑中需要用到的仅仅是Model种的一个或多个字段。在这种情况下，你可以尝试Lists或者Iterables工具集中的transform方法来抽取我们需要的部分。位于Lists包内的函数签名为:
<pre><code class="Java">public static &#60;F, T&#62; List&#60;T&#62; transform(List&#60;F&#62; fromList, Function&#60; ? super F, ? extends T&#62; function);</code></pre>
传入的参数分别为待处理的数据List，以及一个实现具体抽取逻辑的Function。加入我们希望抽取出Node中的id，获得所有Node的id数组。那么我们可以定义如下的Function：传入一个Node，返回该Node的Id。
<pre><code class="Java">Function&#60;Node, Integer&#62; idExtractor = new Function&#60;Node, Integer&#62;() {
        public Integer apply(Node input) {
            return input.getId();
        }
};</code></pre>
然后使用transform即可：
<pre><code class="Java">List&#60;Node&#62; nodes = Lists.newArrayList(
    Node.nodeGenerator(1), Node.nodeGenerator(2), Node.nodeGenerator(3));
List&#60;Integer&#62; nodeIds = Lists.transform(nodes, idExtractor);</code></pre>

使用的语法是非常简单的，但是这背后有一些注意的事项，甚至是隐藏的陷阱。

<!--more-->

####1.1 返回的仅仅是个Lazy的View
最容易犯的错误就是认为上面得到的结果 nodeIds是一个和我们在堆上分配的List一样的东西，但事实是，它不是的。更加准确的说，他甚至还不是他自己。为什么这么说呢？Lists是一个包含若干工具方法的类，可以理解为是博文Part One里面提到的组装场地，在这里数据和逻辑相互作用，具体的，transform方法会返回一个Guava自定义的List, 这种List并不会重新开辟内存来保存transform的返回值，它的内部仅仅保存了一个指向传入数据的引用，其get方法返回Function作用后的结果。当你用迭代器迭代这个List（包括foreach）的时候，会产生一个自定义的iterator：TransformedListIterator。这个iterator的next()返回被Function作用后的结果，迭代器禁用了set和add方法。他扩展了AbstractList，但并没有自己实现add和set方法，所以这两种操作也不被支持。总结一下：

+ 直接调用返回List的 add，set方法会抛出 <font color="red">UnsupportedOperationException</font>；
+ 视图直接操作返回List的Iterator来执行set，add，将会抛出<font color="red">UnsupportedOperationException</font>；
+ 直接调用返回List的remove或者用iterator来remove都会触发传入的原始数据的remove。所以如果传入的原始数据支持这个操作，那么你的操作就会成功。像上面传入的ArrayList，remove是支持的。所以transform的返回也是支持的。需要注意的是，你以为删除的是id，<font color="red">但是删除的实际是原始数据中的对象</font>；

另外需要注意的是，使用transform后你并没马上获得这个List，当你实际使用的时候才会生成，亦即lazy。如果你需要实际修改返回的List，那么需要显式的将结果拷贝出来。
<pre><code class="Java">List&#60;Integer&#62; nodeIds_supportModification = Lists.newArrayList(Lists.transform(nodes, idExtractor));</code></pre>

####1.2警惕你的异常被吞掉
在实现Function中的apply的时候，你或许会调用一个抛出checked异常的函数。但是你的IDE会给你一个错误，因为你Override的apply方法并没有抛出任何checked异常，为了规避这个问题，你可以把一个checked的异常转化为一个Runtime异常来抛出，从而让程序正常的编译，如下：

<pre><code class="Java">Function&#60;Node, Integer&#62; exceptionFunction = new Function&#60;Node, Integer&#62;() {
    public Integer apply(Node input) {
        try {
            input.strangeGet(); //throws a checked exception here
            return input.getId();
        } catch (MyException e) {
            throw Throwables.propagate(e);  //transfer to unchecked exception
        }
    }
};
//checked exception is swallowed 
List<Integer> ids = Lists.transform(nodes, exceptionFunction);</code></pre>
编译没有问题，看样子一切都还不错，但是这里隐藏了一个陷阱，我们把一个需要检查的异常变成了一个运行时异常，为了使用Guava的特性，我们为程序引入了不确定性，为了弥补上面的问题，我们需要在调用的transform的时候显式的捕捉运行时异常。
<pre><code class="Java">try {
    ids = Lists.transform(nodes, exceptionFunction);
} catch (Exception e) {
    throw new MyException(e);
}</code></pre>
但是这样使用Guava，反而让代码变得难以解读，所以当apply中需要使用抛异常的函数时，是否要或者如何使用Guava是需要权衡的。

####1.3 序列化会序列化全部
当你认为你可以放心的序列化transform的返回是，可能结果并非如你所愿。首先你需要确保你的原始数据和传入的Function本身是支持序列化的。另外，当你尝试序列化transform的返回结果是，你实际序列化的其实是整个原始队列加上那个Function。倘若你的原始数据是个不小的对象，而你误以为你仅仅序列了你抽取的数据，那么可能会引入性能的损失。

###2. 使用MultiMaps聚类

Guava官方文档对于MultiMap的解释可能会让你豁然开朗。“几乎所有的程序员都实现过类似于Map<K, List<V>>这样的数据结构。” 啊哈，没错吧，我们都曾经纠结的，无数次的使用过这种数据机构，而且使用大量并不易读的嵌套来遍历这种数据结构，其结果是让自己都不喜欢自己的代码。MultiMap的在一定程度上会缓解这种情况。

我们使用这样一个场景来介绍MultiMap的用法。我们从学校的学生数据库中拉取了一个List的学生信息，每个学生的信息中有一个country的字段描述TA所来自的国家，而我们希望按照按国家来统计和处理这些学生。对于这个用例，我们可以使用index方法，其函数签名如下：

<pre><code class="Java">public static &#60;K, V&#62; ImmutableListMultimap&#60;K, V&#62; index(
      Iterable&#60;V&#62; values, Function&#60; ? super V, K&#62; keyFunction)</code></pre>
接受一个可迭代对象，已经一个用于index的函数，经过函数作用的Value，其结果将会作为生成的MultiMap的Key值。所以我们学生的用例，需要一个如下的Function，并将其传入MultiMaps下的index方法即可

<pre><code class="Java">Function&#60;Student, Integer&#62; countryIdExtractor = new Function&#60;Student, Integer&#62;() {
    public Integer apply(Student input) {
        return input.getCountryId();
    }
};
Function&#60;Student, Integer&#62; countryIdExtractor = new Function&#60;Student, Integer&#62;() {
    public Integer apply(Student input) {
        return input.getCountryId();
}；

ListMultimap&#60;Integer, Student&#62; countryIdToStudents = Multimaps.index(students, countryIdExtractor);</code></pre>

我们获得的是一个由学生国家代码作为Key，属于该国家的所有学生集合作为Value的数据结构。对于返回值，有一些是需要我们注意的：

+ 返回的结果并没有按照Key的值进行排序，Key的出现顺序和原始集合中作为index对象的（这里是countryId）出现顺序是一致的。其原因是Guava的内部，index也是一个Key到List（或者Set）的结构体，然后顺序遍历原始数据，把经过Function相同的对象放到一起。如果你想得到经过按照Key值排序的的返回，那么可以通过首先排序原始数据，再执行index来做。注意这里涉及到一次排序，所以会多使用一倍的空间。
<pre><code class="Java">ListMultimap&#60;Integer, Student&#62; orderedCountryIdToStudents = Multimaps.index(
        Ordering.natural().onResultOf(new Function&#60;Student, Integer&#62;() {
            public Integer apply(Student input) {
                return input.getCountryId();
            }
        }).sortedCopy(students),
        countryIdExtractor
    );</code></pre>

+ 返回的结构体是Immutable的，意味着不能够改变，具体的，以下的几个函数无法在传回的ListMultiMap上使用（会抛出UnSupportedOperation异常）：<span style="background-color: #D8D8D8"><font color="black">removeAll</font></span>, <span style="background-color: #D8D8D8"><font color="black">replaceValues</font></span>, <span style="background-color: #D8D8D8"><font color="black">remove</font></span>, <span style="background-color: #D8D8D8"><font color="black">clear</font></span>, <span style="background-color: #D8D8D8"><font color="black">put</font></span>, <span style="background-color: #D8D8D8"><font color="black">putAll</font></span>. 但是我们依然可以在不改变结构体的情况下具体修改某个或全部element内的值，这是允许的。
<pre><code class="Java">for(Integer countryId : orderedCountryIdToStudents.keySet()){
        if (CountryEnum.CHINA.getCountryCode.equals(countryId) {
            for(Student student : orderedCountryIdToStudents.get(countryId)){
                student.setDescription("Normally Good at Examming.");
            }
        }
    }</code></center></pre>

+ 如果传入的K, V都是支持串行化的，那么返回的结果也是支持串行化的。 

+ 在Map上使用MultiMaps的工具
上面的MultiMaps中的index方法接受一个集合，但是如果拿到手上的是一个Map，然后我想知道某个对应同样Value的有多少Key，这种需求类似Hadoop的hello world就是来做技术，设想我们有一个Map记录了每个字母在文章中出现的数目，然后想知道数目为X的字母有哪些。我们依然可以使用MultiMaps工具类，这里使用了forMap方法把一个Map类型结构转换成了一个SetMultiMap, Key为原始Key，只是Value被视作了一个Set。这里传入的Map还是那个Map，并没有任何的变化，Guava实现了一个自定义的迭代器，用来在使用get的时候返回一个Set。把这个转换后的MultiMap传递给invertForm方法，并传入盛放结果的地方。
<pre><code class="Java">Map<String, Integer> map = ImmutableMap.of("a", 1, "b", 1, "c", 2);
    SetMultimap<String, Integer> multimap = Multimaps.forMap(map);
    // multimap maps ["a" => {1}, "b" => {1}, "c" => {2}]
    Multimap<Integer, String> inverse = Multimaps.invertFrom(multimap, HashMultimap.<Integer, String> create());
    // inverse maps [1 => {"a", "b"}, 2 => {"c"}]</code></pre>
个人觉得forMap实现的挺好的，要善于用迭代器来实现容器相关的操作，而不要生硬的每次开辟新的内存。参考下面的代码。
<pre><code class="Java">@Override
public Set&#60;V&#62; get(final K key) {
    return new Sets.ImprovedAbstractSet&#60;V&#62;() {
        @Override public Iterator&#60;V&#62; iterator() {
          return new Iterator&#60;V&#62;() {
            int i;
            @Override
            public boolean hasNext() {
              return (i == 0) && map.containsKey(key);
            }
            @Override
            public V next() {
              if (!hasNext()) {
                throw new NoSuchElementException();
              }
              i++;
              return map.get(key);
            }
            @Override
            public void remove() {
              checkRemove(i == 1);
              i = -1;
              map.remove(key);
            }
          };
        }
        @Override public int size() {
          return map.containsKey(key) ? 1 : 0;
        }
    };
}</code></pre>

+ 有关多线程
上面的方法，index返回的ImmutableMultiMap本身是线程安全的，可以在多线程环境下使用。但是invertFrom返回的结果是MultiMap，并不是线程安全的，当在一个多线程环境下使用时，需要满足Guava的规约才可以。Guava提供了一个名为<span style="background-color: #D8D8D8"><font color="black">Synchronized</font></span>的工具类，用来包装一个MultiMap为一个thread-safe的数据结构。具体的，假设一个名为<span style="background-color: #D8D8D8"><font color="black">students</font></span>的MultiMap 需要由多个线程访问，需要如下操作：
<pre><code class="java">ListMultimap<Integer, Student> threadSafeMultiMap = Multimaps.synchronizedListMultimap(students);
//no need to put it inside a synchronized block
    List<Student> studentsFromUSA = threadSafeMultiMap.get(CountryEnum.USA.getCountryCode()); 
    //need to synchronize multiMap, NOT the map value you are going to iterate
    synchronized (threadSafeMultiMap){
        Iterator<Student> iterator = studentsFromUSA.iterator();
        while (iterator.hasNext()){
            doSomeThing(iterator.next());
        }
    }</code></pre>


###3. Iterables工具集
Iterables工具集提供了一些暗黑小科技，可以在一定程度上简化我们的开发工作。假设我们操作的数据来自多个数据源，但是在最后处理的过程中，希望用一次遍历，那么我们可以使用<span style="background-color: #D8D8D8"><font color="black">Iterables.contact</font></span>，返回的结果是链接了若干个Iterable的集合的lazy view，并没有开辟新的空间，然后我们就可以使用一次迭代完成对若干个集合的遍历了。
<pre><code class="Java">ImmutableList&#60;Integer&#62; immutableList1 = ImmutableList.of(1, 2, 3, 4);
ImmutableList&#60;Integer&#62; immutableList2 = ImmutableList.of(1, 2, 3, 4);
Iterable&#60;Integer&#62; immutableListConcat = Iterables.concat(immutableList1, immutableList2);
Iterator&#60;Integer&#62; immutableIterator = immutableListConcat.iterator();
while (immutableIterator.hasNext()){
    if (immutableIterator.next() == 1 ) {
        immutableIterator.remove(); //unsupported operation
    }
}</code></col></pre>
注意到concat的结果集合具有和原集合相同的mutability，上面代码的异常是因为原始集合immutable造成的。由于contact返回的是一个lazy的view，意味着即使你在concat之后对原集合进行的修改，这种修改在你真正遍历concat结果的时候都会反映出来。除此之外，Iterables集合还有几个顺手的小工具：

+ <span style="background-color: #D8D8D8"><font color="black">Iterables.frequency(Iterable&#60;?&#62; iterable, @Nullable Object element)</font></span>，计算某个元素在Iterables中出现的次数；
+ <span style="background-color: #D8D8D8"><font color="black">Iterables.partition(final Iterable&#60;T&#62; iterable, final int size)</font></span>，把Iterables按照指定的大小分组，例如一个包含5个元素的集合，按2分组，则会得到[0, 1], [2, 3], [4]的三个集合;
+ <span style="background-color: #D8D8D8"><font color="black">elementsEqual(Iterable&#60;?&#62; iterable1, Iterable&#60;?&#62; iterable2)</font></span>，判断两个集合是否包含同样的元素，按照同样的顺序

Guava还提供了一个在Java8才能使用的Streaming方式，当然，由于Guava的函数式变成支持并不是是非彻底，所以Guava提供的Streaming并没有Java8强大，但是，始终，在大量项目嗨停留在java6/7的阶段，Guava的Streaming方式还是可以给代码带来令人愉快的变化。GuavaG是通过<span style="background-color: #D8D8D8"><font color="black">FluentIterable</font></span>这个类来实现类Streaming编程的。举个简单的例子来展示FluentIterable：
<pre><code class="java">Predicate&#60;Student&#62; chineseMale = new Predicate&#60;Student&#62;() {
    public boolean apply(Student input) {
        return Gender.MALE.equals(input.getGender()) && CountryEnum.CHINA.equals(input.getCountry());
    }
};
Function&#60;Student, String&#62; getName = new Function&#60;Student, String&#62;() {
    public String apply(Student input) {
        return input.getName();
    }
};
//获得所有来自中国的男同学的名字，取前三个并按照字母序排列
List&#60;String&#62; nameList = FluentIterable.from(students).filter(chineseMale).transform(getName).toSortedList(Ordering.&#60;String&#62;natural());</code></pre>

是不是有种很流畅的感觉。而且返回的值是lazy的，只有你真正使用它的时候才会计算。



未完待续...


Sincerely,<br>
<a href="https://twitter.com/stevenyfy"><font color="green">@stevenyfy</font></a>


<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png" /></a><br />This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/">Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License</a>.

