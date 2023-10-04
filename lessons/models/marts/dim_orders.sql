with orders as (
	select *

	from {{ ref('stg_ecommerce__orders') }}
),

order_items_products as (
	select *

	from {{ ref('int_ecommerce__order_items_products')}}
),

first_order_created as (
	select *

	from {{ ref('int_ecommerce__first_order_created') }}
),

order_items_measures as (
	select
		order_id,
		sum(item_sale_price) as total_sale_price,
		sum(product_cost) as total_product_cost,
		sum(item_profit) as total_profit,
		sum(item_discount) as total_discount,
		{% for department in dbt_utils.get_column_values(table=ref('int_ecommerce__order_items_products'), column='product_department') %}
		SUM(IF(product_department = '{{ department }}', item_sale_price, 0)) as total_sold_{{ department.lower() }}swear{{ "," if not loop.last }}
		{%- endfor %}

	from order_items_products

	group by 1
),

final as (
	select
		o.order_id,
		o.user_id,
		o.created_at as order_created_at,
		{{ is_weekend('o.created_at') }} as order_was_created_on_weekend,
		o.returned_at as order_returned_at,
		o.shipped_at as order_shipped_at,
		o.delivered_at as order_delivered_at,
		o.status as order_status,
		o.num_of_item as num_items_ordered,
		oim.total_sale_price,
		oim.total_product_cost,
		oim.total_profit,
		oim.total_discount,
		TIMESTAMP_DIFF(o.created_at, foc.first_order_created_at, DAY) AS days_since_first_order,

		{%- for department in departments %}
		total_sold_{{ department.lower() }}swear{{ "," if not loop.last }}
		{%- endfor %}

	from orders o
	left join order_items_measures oim
		on oim.order_id = o.order_id
	left join first_order_created foc
		on o.user_id = foc.user_id
)

select * from final