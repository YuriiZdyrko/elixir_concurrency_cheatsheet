https://norbertka.me/posts/dynamic_genstage_producers/

Practiced:
- dealing with failing Producer by using `subscribe_to: [cancel: :transient]`
- using :one_for_one, :one_for_all strategies to deal with too frequent restarts of Producer worker