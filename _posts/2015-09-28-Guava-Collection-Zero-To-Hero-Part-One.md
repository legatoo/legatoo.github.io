---
title: Guava Collection Zero To Hero Part One
date: 2015-09-28 00:00:00 Z
layout: post
---

好长时间都没有更新这里了。所以说学生时代还是最好的时间嘛，晚睡晚起，想写就写。闲话少说了，这篇博客主要介绍下最近使用Guava的一些特性，集中在最常使用的Collection部分，希望通过正确使用Google Guava，美化Java代码，提高可读性，可维护性。在Part One里面会主要介绍Guava的背景和顺畅使用Collection所必须的一些前置知识。

##一些Guava的背景
众所周知，Guava是Google的一款开源库。他的前身是Google在2007年10月22日首发的[Google Collection](https://code.google.com/p/google-collections/)，随着2009年底Guava的正式开放，Google Collection变成了Guava的一个子集。有人认为是Java5发布引入的泛型（Generics）是Google最终决定停止维护Apache Commons，转而开发自己的类库的[导火索](https://code.google.com/p/google-collections/wiki/Faq#Why_did_Google_build_all_this,_when_it_could_have_tried_to_impro)。简单总结一下Google的初衷：

+ 当时的Apache Library基于Java 1.4，他们不喜欢1.4
+ Apache Library由于上面一点，不支持泛型，导致使用者的代码中出现大量的编译时warning
+ Apache Collections在实现上有不少和JDK本身集合行为相异的地方。Google认为完全没有必要引入这种风险

关于一个公司为什么开源一个软件，系统，或者工具，不同的人有不同的解读。除了上述的几点之外，Guava的主要贡献者kevinb9n在2014年[Reddit](https://www.reddit.com/r/java/comments/1y9e6t/ama_were_the_google_team_behind_guava_dagger)上的答网友问中的观点让我觉得非常值得思考。他提到当Google在内部不断地囤积秘密代码库方便开发的时候，Google的程序员可能和外部的Java世界渐行渐远，Google希望自己的工程师依旧和主流站在一起，缩小Java Inside Google和Java Outside Google之间的区别。所以吾等，如果抱着身处Google之外就处在主流之中的错误想法，那么很有可能忽略Google等公司对主流的改造，最终的结果可能是我们变成了非主流。所以还是要发现变化，理解变化，忍受抑或享受变化。

Guava开放之后当然是收到了主流的欢迎。究其原因主要的有三，首当其冲的是良好的设计，Guava的开发由一群优秀的工程师担任，除此之外，还有Joshua Bloch的亲自指导，可能你忘了他是说，Effective Java，好了，你知道了。第二个原因是Guava是经过严格的测试，Google的诸多业务都有Guava的身影，所有外部commit（基本上）都是不被接受的，Google用Eat Your Own Dogfood的行为保证了Guava的稳定。第三就是品牌效应，活跃社区。综上，Guava成为了Java类库里面一款比较成功的产品。


##Function是什么
在开始讨论之前如果对Guava的Function不了解，那么集合的操作也就不能发挥出最大的优势了。[Functional Programming](https://en.wikipedia.org/wiki/Functional_programming)实在不是我目前了解的，但是这里还是跳不过去，不懂得函数是编程，但是至少需要知道什么是函数。这篇[博客](http://maryrosecook.com/blog/post/a-practical-introduction-to-functional-programming)里面讲到了两条基本的原则，我认为可以很好的帮助我们对照理解Guava中的Function。他提到一个Functional的函数需要具备两个条件：

+ 不依赖函数外的数据
+ 不修改函数外部存在的数据

下面有两段Python的方法，可以用来体会他们的区别：
<p><img src="{{site.baseurl}}public/img/image/what-is-functional-1.png"/></p>

Guava的Function也满足这样的特质。在我自己的角度来看，我会把上面两段代码进行如下的拆解：
<p><img src="{{site.baseurl}}public/img/image/what-is-functional-2.png"/></p>

函数化的函数可以作为独立的组件，独立于要操作的数据，独立于数据与函数相互作用的场地而存在。当把函数作为一种组件而传递的时候，你会发现一种突然迎面而来的清晰感，数据，逻辑，场地，井然有序的排列开了。Guava为我们提供了一些场地，例如`transform`, `index`等都是Guava为我们提供好的场地，同时，Guava为我们提供了可自定义的Functional Function接口，可以将我们的逻辑封装为可传递的组件，最后不论是JDK的Collection还是Guava的Collection，都可以在Guava的场地中和Function发生作用，带给我们一种很不一样的编程感受。

对Function有了一个基本的认识之后，可以开始编写和使用Guava的Function了。 只要实现下面的Guava提供的接口，便可以书写自己的Function。

<!--more-->

<pre><code class="Java">public interface Function&#60;F, T&#62; {
  @Nullable T apply(@Nullable F input);
  @Override boolean equals(@Nullable Object object);
}</code></pre>
其中的equals代表函数的等价性，两个等价函数作用于同一个对象，结果也应该是相等的。绝大多数情况都没有必要去重写这个方法。怎么理解那两个传入的泛型呢：第一个代表你要操作的数据类型，第二个代表函数返回的类型。所以让我们用Guava重写上面的加法函数：
<pre><code class="Java">Function&#60;Integer, Integer&#62; increment = new Function&#60;Integer, Integer&#62;() {
    public Integer apply(Integer input) {
        return input + 1;
    }
};</code></pre>
有了这个方法，我们可以在某个Guava提供的场地内，让他与数据发生作用，后面再具体的用力部分会看到Functin如何和Collection一起使用。Guava还提供了一个名为Functions的工具类，其中有两个有一定的实用价值。

+ forMap(Map<K,? extends V> map, V defaultValue)

他的功能乍一看来是有点多余的，无非就是用来查询Map，但是用get不可以么？区别于get的是，Guava的forMap允许在查询的时候对于不存在的key提前设定一个默认值。这个细小的改进或许可以让你的代码更加流畅，举个例子，加入我们有一个需要组装的短信模板：“Hello, {name}. Welcome to {place}. Show starts at {time}.” 下面的方式是传统的方法:

<pre><code class="Java">String patternStr = "(\\{([^\\}]+)})";
Matcher matcher = Pattern.compile(patternStr).matcher(SmsTemplate.SMS);
StringBuffer result = new StringBuffer();

while(matcher.find()){
    String matchStr = matcher.group(2); //what inside {}
    if(smsParts.containsKey(matchStr)){
        matcher.appendReplacement(result,  matchStr);
    }else{
        matcher.appendReplacement(result, "");
    }
}
matcher.appendTail(result);</code></pre>
我们看到为了处理不存在key的逻辑，使得代码显得很臃肿。尝试用Guava重写:
<pre><code class="Java">StringBuffer result = new StringBuffer();
Function&#60;String, String&#62; lookup = Functions.forMap(smsParts, "");
while (matcher.find()){
    matcher.appendReplacement(result, lookup.apply(matcher.group(2)));
}
matcher.appendTail(result);</code></pre>
有没有一种代码逻辑清晰一点的感觉。这是forMap的使用，相信你可以开发出更多。

+ compose(Function<B,C> g, Function<A,? extends B> f)

他的功能是把两个函数串联起来使用，使用顺序是先后面的函数f，再前面的函数g。达到的效果是 <span style="background-color: #084B8A"><font color="white">B-->A-->C</font></span>的处理流。由于forMap函数可以给查找不到的Key给默认值，所以可以比较方便的被compose。举个例子，我们希望找出一个Map中Key值为特定值的一些value，然后对他们进行一些处理，将结果保存为一个数据，这些逻辑用Guava的流式处理可以一句话完成。

<pre><code class="Java">Function&#60;Integer, Node&#62; lookup = Functions.forMap(mapData, null);
Function&#60;Node, String&#62; process = new Function&#60;Node, String&#62;() {
    public String apply(Node input) {
        //do something, return null if input is null
    }
};
Function&#60;Integer, String&#62; compose = Functions.compose(process, lookup);

List&#60;String&#62; joinResult_guava_notnull =
    FluentIterable.from(keys).transform(compose).filter(Predicates.notNull()).toList();</code></pre>
这里的keys是指定的一组key，然后连续使用两组Function的组合，具体的，每个我们指定的key会先传递给lookup方法在map中进行查找，如果没有则返回null，查找到的值紧接着传递给process方法进行处理。最后呢，用filter过滤掉由于默认值带来的null，完成。当然同样的逻辑用Java写也并不会多几行，所以这个例子更多的是个风格问题，看你喜欢if-else的罗列还是尝试Guava的Function加流式处理。

除了Function之外，还有一个叫做[Predicate](https://code.google.com/p/guava-libraries/wiki/FunctionalExplained#Predicates)的接口，常常用来集合过滤，使用Predicate可以在一定程度上让代码的可读性得到提高。举个例子，看下面的代码：
<pre><code class="Java">//返回key在一个范围内的所有entries,guava实现
Map&#60;Integer, Model&#62; subMap_guava = Maps.filterKeys(users, Predicates.in(Lists.newArrayList(1, 2)));
//传统实现
Map&#60;Integer, Model&#62; subMap = new HashMap&#60;Integer, UserModel&#62;(users);
subMap.keySet().retainAll(Lists.newArrayList(1, 2));</code></pre>
注意使用Predicate过滤的集合，返回都是lazy的immutable的view，但相比与传统的写法，我们不得不建立一个新的集合。如果是只读操作的话，用Guava的方式可以避免不必要的集合创建。Predicate的更多使用方法和Function类似，这里不作介绍。

##ImmutableCollection的使用以及注意事项

学生时代我用Java，没有接触过（甚至思考过）什么是ImmutableCollection，知道实习，工作，才发现有的时候是需要这种数据结构的。他的确有一些吸引人的地方：

+ 避免因为无意或恶意的修改本不需要修改的数据造成的Bug（防御式编程），就像把参数用final修饰传入方法总是让人放心一点
+ Immutable的数据结构是线程安全的，可以被多个线程安全的读取
+ 占用更少的空间，给程序瘦身

Guava有一套自己的Immtable集合，提供了List，Set，Map等常用数据结构的Immtable封装。除了不少Guava的工具都返回Immtable的结果外，Guava提供了<span style="background-color: #D8D8D8"><font color="black">copyOf</font></span>方法用来把标准集合转换为Immtable版本。例如：
<pre><code class="Java">ImmutableSet.copyOf(set);
ImmutableList.copy(list);
ImmutableSet.of("a", "b", "c");
ImmutableMap.of(1, "a", 2, "b");
//or using Builder
ImmutableMap<Integer, String> immutableMap = new ImmutableMap.Builder<Integer, String>()
        .put(1, "a")
        .put(2,  "b")
        .build();</code></pre>

对于ImmtableCollection的内存footprint，Guava还提供了一个非常handy的工具，可以检查数据结构的内存使用情况。其地址在<a href="https://github.com/msteindorfer/memory-measurer">memory-measure</a>，他的使用方法也非常简单，如果想直接使用，从<a href="https://drive.google.com/open?id=0B7jjV8XBHXkIREplSDFrR0g4cUk">这里</a>下载我编译好的jar包, 把它引入到工程的libraries中，然后在运行参数中给VM传入：<span style="background-color: #D8D8D8"><font color="black">-javaagent:pathTo/object-explorer.jar</font></span>，然后如下使用即可查看某种数据结构的内存占用情况：
<pre><code class="Java">Map<Integer, Integer> mapFootPrint = new HashMap<Integer, Integer>();
ImmutableMap<Integer, Integer> emptyImmutableMapFootMap = new ImmutableMap.Builder<Integer, Integer>().build();
System.out.println(MemoryMeasurer.measureBytes(mapFootPrint));
System.out.println(MemoryMeasurer.measureBytes(emptyImmutableMapFootMap));</code></pre>

基于上面的工具，我们进一步来对比一下Immutable集合在内存方面的优势：
<a href="{{site.baseurl}}public/img/image/immutablemapVSmap.png" data-lightbox="immutableMap-memory-benchmark" data-title="ImmutableMap and HashMap memory compare"><img src="{{site.baseurl}}public/img/image/immutablemapVSmap.png" alt="why-string-doesnt-cache-hashcode" /></a>
上图显示了传统HashMap（蓝色）和Guava ImmutableMap（橙色）（Key，Value都是Integer）内存footprint的对比。可以看出，Immutable比HashMap更小。除此之外，我们会注意到曲线上有一些明显上升的折点，而这些折点，ImmutabMap总是要比HashMap来的晚一些，这是因为在ImmutableMap身上，Google选取了不同的<span style="background-color: #D8D8D8"><font color="black">LOAD_FACTOR</font></span>。在HashMap中，这个值被设定为0.75，而在ImmutableMap中，这个值被设置为1.2。所以说ImmutableMap默认允许了更多的Hash冲突，推迟了resize的时机。

那么Immutable在读的性能上如何能？是否能做到空间时间都比较优秀呢？
<a href="{{site.baseurl}}public/img/image/accessTimeTestImmutableMapVsHashMap.png" data-lightbox="immutableMap-random-access-benchmark" data-title="ImmutableMap and HashMap random access compare"><img src="{{site.baseurl}}public/img/image/accessTimeTestImmutableMapVsHashMap.png" alt="why-string-doesnt-cache-hashcode" /></a>
很遗憾，ImmutableMap的随机读取并不好，在一亿次请求的时候，所用时间基本上快是HashMap的两倍了。因为在使用Immutable时需要考虑时间上的性能问题。为什么会出现这样的问题呢？这里就引出了使用ImmutableMap和HashMap上实现不一致的一个点，一个隐藏的“危险”： ImmutableMap和HashMap在get的实现上有出入，对于expensive的<span style="background-color: #D8D8D8"><font color="black">hashCode()</font></span>和<span style="background-color: #D8D8D8"><font color="black">equals()</font></span>的对象，使用ImmutableMap进行随机访问，会遇到比较大的性能问题。上面例子中的Integer作为Key就是equals方法过于昂贵的原因：
<pre><code class="Java">public boolean equals(Object obj) {
    if (obj instanceof Integer) {
        return value == ((Integer)obj).intValue();
    }
    return false;
}</code></pre>
为了对比两个Integer是否相同，不得不使用比较昂贵的<span style="background-color: #D8D8D8"><font color="black">instanceof</font></span>操作符，它贵在哪里呢？这里有一个对于他的<a href="http://stackoverflow.com/a/26514984/1285444">benchmark</a>, 根据它的测试数据，我们估算一下调用一亿次的开销：4.2s，注意到上面的测试中，ImmutableMap的一亿次的访问耗时7.3s，那么我们有理由相信，这个昂贵的instanceof大大的削弱了ImmutableMap原本的随机访问性能。（ImmutableMap还采用了不同的hash计算方式，关于hash的<a href="https://lonewolfer.wordpress.com/2015/01/05/benchmarking-hash-functions/">benchmark</a>, <a href="http://www.nurkiewicz.com/2014/04/hashmap-performance-improvements-in.html">and this one</a>可以参考这一个项目，个人认为Guava ImmutableMap采用的Hash可能要比HashMap的好，输在instanceof上面）。

Integer做Key体现了一个昂贵的equals带来的问题，除此之外，还有一点明显的区别会影响Immutable的性能，就是ImmutableMap并没有像HashMap在Entry中缓存Key的hashCode，因此对于拥有昂贵的hashCode的对象做Key，Immutable同样不适用。
下面的截图是ImmutableMap和HashMap的get函数（左Immutbale，右HashMap）：

<a href="{{site.baseurl}}public/img/image/codeCompareMapGet.png" data-lightbox="different-get-implementation-map" data-title="Different get implementations in ImmutableMap and HashMap"><img src="{{site.baseurl}}public/img/image/codeCompareMapGet.png" alt="why-string-doesnt-cache-hashcode" /></a>

在使用String数据类型作为Key的时候，在大量数据面前，会出现比较显著的性能问题，究其原因，还是因为String并没有在对象内部保存自己的Hash值（Java7依旧）每次需要计算hashCode。

这里引申一点点，为什么String不在创建的时候就缓存好自己的hashCode以供以后使用呢？从Java发展一开始到现在，持续有开发者建议在String类中缓存自己的HashCode，但是开发组没有采纳，大家的观点基本上可以用下面的图片概括：

<p><img src="{{site.baseurl}}public/img/image/StringWhyNotCacheHash.png"/></p>

开发人员基于上面的“结论”，选择不在String浪费空间，和（主要是）时间来计算String对象的HashCode。但是为了避免String做Map Key带来的性能问题，Java把Key的hashCode缓存在了Map的Entry中。因为Immutable并没有缓存hashCode，因此，如果使用ImmutableMap，并且使用带有昂贵hashCode方法的对象做Key，我们应该尝试在对象中缓存hashCode来避免性能的影响，或者，使用HashMap。

本文完。（Part Two会带来更多的Guava的使用场景。Stay Tuned.）


Sincerely,<br>
<a href="https://twitter.com/stevenyfy"><font color="green">@stevenyfy</font></a>


<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png" /></a><br />This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/">Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License</a>.
