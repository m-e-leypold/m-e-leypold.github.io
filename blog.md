---
layout: default
title:  Blog
---

<ul>
  {% for post in site.posts %}
    <li>
      <b>{{ post.date | date: "%Y-%m-%d" }}</b> -- 
      <a href="{{ post.url }}">{{ post.title }}</a
      >{% if post.excerpt %}: 
               {{ post.excerpt | strip_html | strip_newlines }} <a href="{{ post.url }}">…</a> 
       {%endif %}
    </li>
  {% endfor %}

  <!-- This is far from perfect -->
</ul>
