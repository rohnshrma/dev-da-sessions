/* =====================================================================
   SUBQUERIES — CLASS 1
   =====================================================================

   WHAT IS A SUBQUERY?
   -------------------
   A subquery (also called an "inner query" or "nested query") is a
   SELECT statement written INSIDE another SQL statement.
   The query that contains it is called the "outer query".

       SELECT ...                      <-- outer query
       FROM ...
       WHERE col IN (SELECT ... )      <-- inner query (subquery)

   The database runs the inner query first (conceptually), and the
   outer query then uses its result as if it were a value, a list of
   values, or a table.

   Rules to remember:
     * A subquery is always wrapped in parentheses ( ... ).
     * A subquery used in FROM must be given an alias (a name).
     * A subquery used where ONE value is expected must return exactly
       one row and one column, otherwise you get an error.

   TYPES OF SUBQUERIES (by what they RETURN)
   -----------------------------------------
   1. Scalar subquery      -> returns ONE value (1 row x 1 column).
                              Can be used anywhere a single value can:
                              SELECT list, WHERE col = (...), etc.
                              Example 1 below.

   2. Multi-row subquery   -> returns ONE column but MANY rows
      (list subquery)         (a list of values). Used with
                              IN, NOT IN, ANY, ALL, EXISTS.
                              Example 3 below.

   3. Multi-column /       -> returns MANY rows and MANY columns,
      Table subquery          i.e. a whole temporary table.
      (Derived table)         Used in the FROM clause and must have
                              an alias.
                              Example 2 below.

   TYPES OF SUBQUERIES (by HOW they run)
   -------------------------------------
   a. Non-correlated subquery -> independent of the outer query. It can
                                 be run on its own and runs ONCE.
                                 (All three examples in this file are
                                 non-correlated.)

   b. Correlated subquery     -> refers to a column of the outer query,
                                 so it is re-evaluated for EVERY row of
                                 the outer query. Example:
                                   SELECT e.full_name, e.fee_paid
                                   FROM raw_enrollments e
                                   WHERE e.fee_paid > (
                                       SELECT AVG(x.fee_paid)
                                       FROM raw_enrollments x
                                       WHERE x.course = e.course   -- uses outer row
                                   );
                                 (students who paid more than the average
                                 fee of THEIR OWN course)

   WHERE CAN A SUBQUERY BE PLACED?
   -------------------------------
     * SELECT clause  -> scalar subquery as a computed column  (Example 1)
     * FROM clause    -> derived table                         (Example 2)
     * WHERE / HAVING -> filter using =, >, IN, EXISTS ...     (Example 3)

   CONTEXT FOR THIS FILE
   ---------------------
   We are cleaning a messy table "raw_enrollments". The enrollment_id
   column was typed by hand, so the same ID can appear in different
   forms, e.g.  'wg-101', ' WG-101 ', 'WG101'. We want to find out
   how many real duplicates exist.
   ===================================================================== */



/* ---------------------------------------------------------------------
   EXAMPLE 1 : SCALAR SUBQUERIES IN THE SELECT LIST
   ---------------------------------------------------------------------
   Each subquery below returns exactly ONE number. We place three of
   them side-by-side so we get a one-row "summary report".
   Notice there is no FROM clause in the outer query — the outer SELECT
   only displays the values the inner queries return.
   --------------------------------------------------------------------- */
SELECT                                          -- outer query starts; it just shows 3 values
(SELECT COUNT(*) from raw_enrollments) as total_rows,
    -- scalar subquery #1: COUNT(*) counts every row in the table
    -- (duplicates included). Result is named "total_rows".

(SELECT COUNT(DISTINCT enrollment_id) from raw_enrollments) as ids_as_typed,
    -- scalar subquery #2: COUNT(DISTINCT col) counts only the UNIQUE
    -- values of enrollment_id exactly as they were typed.
    -- 'WG-101' and 'wg-101 ' are treated as DIFFERENT here.

(SELECT COUNT(DISTINCT UPPER(TRIM(enrollment_id))) from raw_enrollments) as ids_after_trim;
    -- scalar subquery #3: before counting unique values we clean them:
    --   TRIM(x)  -> removes leading/trailing spaces   ' wg-101 ' -> 'wg-101'
    --   UPPER(x) -> converts to capital letters       'wg-101'   -> 'WG-101'
    -- Now 'wg-101 ' and 'WG-101' count as the SAME id.
    --
    -- Reading the result:
    --   total_rows  >  ids_as_typed    -> there are exact duplicates
    --   ids_as_typed > ids_after_trim  -> some "unique" ids were really
    --                                     the same id with spaces/case
    --                                     differences.



/* ---------------------------------------------------------------------
   EXAMPLE 2 : SUBQUERY IN THE FROM CLAUSE  (DERIVED TABLE)
   ---------------------------------------------------------------------
   Question: which ids appear more than once ?

   Idea:
     Step 1 (inner query) -> clean every id and count how many times
                             each clean id occurs. This produces a small
                             temporary table with 2 columns:
                             (clean_id, copies).
     Step 2 (outer query) -> read from that temporary table and keep
                             only rows where copies > 1.

   Why a subquery? The column alias "copies" is created inside the
   inner query. A WHERE clause cannot use an alias defined in the same
   SELECT, but once the result is wrapped as a derived table, the outer
   query can treat "copies" like a normal column.
   --------------------------------------------------------------------- */

-- which ids appear more than once ?
select clean_id , copies              -- outer query: pick the 2 columns produced by the derived table
from (                                -- the FROM clause reads from a subquery instead of a real table
	select                            -- inner query starts

		REGEXP_REPLACE(upper(trim(enrollment_id)), '^WG-?','WG-') as clean_id,
		-- Cleaning the id in 3 steps (innermost function runs first):
		--   1. trim(enrollment_id)  -> remove extra spaces
		--   2. upper(...)           -> make everything capital
		--   3. REGEXP_REPLACE(text, pattern, replacement)
		--        pattern '^WG-?' means:
		--          ^   -> at the START of the text
		--          WG  -> the letters W G
		--          -?  -> an optional hyphen (0 or 1 '-')
		--        replacement 'WG-' -> always write it as 'WG-'
		--      so 'WG101' -> 'WG-101'  and  'WG-101' stays 'WG-101'.
		-- The cleaned value is given the alias "clean_id".

		count(*) as copies from raw_enrollments
		-- count(*) counts the rows in each group (see GROUP BY below)
		-- and names that number "copies". Data comes from raw_enrollments.

		group by REGEXP_REPLACE(upper(trim(enrollment_id)), '^WG-?','WG-')
		-- GROUP BY puts all rows with the same CLEANED id into one group,
		-- so count(*) above tells us how many rows share that clean id.
		-- (We repeat the full expression because some databases do not
		-- allow GROUP BY on an alias.)
) as d
-- "as d" gives the derived table a name. This alias is REQUIRED:
-- every subquery in the FROM clause must have one.

where copies > 1
-- the outer query can now filter on "copies" — keep only ids that
-- occur 2 or more times, i.e. the duplicates.

order by copies desc , clean_id;
-- sort: most-duplicated ids first; ties are sorted alphabetically by id.



/* ---------------------------------------------------------------------
   EXAMPLE 3 : MULTI-ROW SUBQUERY IN THE WHERE CLAUSE  (with IN)
   ---------------------------------------------------------------------
   Example 2 told us WHICH ids are duplicated, but it only showed the
   id and a count. Now we want to see the FULL original rows (name,
   city, course, fee) for every duplicated id, so we can decide which
   copy to keep.

   Idea:
     Inner query -> returns a LIST (one column, many rows) of clean ids
                    that occur more than once.
     Outer query -> returns every row of raw_enrollments whose clean id
                    is IN that list.
   --------------------------------------------------------------------- */
select enrollment_id , full_name, city , course , fee_paid from raw_enrollments
-- outer query: the columns we want to inspect, straight from the raw table

where  REGEXP_REPLACE(upper(trim(enrollment_id)), '^WG-?','WG-') IN (
-- clean the id of the current row (same cleaning as before) and check:
-- is this clean id present IN the list returned by the subquery below?
-- IN (...) is TRUE if the value matches ANY value in the list.

	SELECT REGEXP_REPLACE(upper(trim(enrollment_id)), '^WG-?','WG-')
	-- inner query returns ONE column: the cleaned id
	FROM raw_enrollments
	-- from the same table
	group by 1
	-- "group by 1" = group by the 1st column in the SELECT list
	-- (a shortcut for repeating the whole REGEXP_REPLACE expression)
	having count(*) > 1
	-- HAVING filters GROUPS (WHERE filters rows). Keep only clean ids
	-- whose group has more than 1 row -> the duplicated ids.

);
-- Result: every original row that belongs to a duplicated id, showing
-- how the same student was entered multiple times.
--
-- NOTE: the inner query does not reference the outer query, so it is a
-- NON-CORRELATED subquery: it runs once, builds the list, and the
-- outer query checks each row against that list.
