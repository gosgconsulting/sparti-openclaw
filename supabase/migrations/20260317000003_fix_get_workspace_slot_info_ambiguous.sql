-- Fix ambiguous column reference in get_workspace_slot_info: the RETURNS TABLE
-- column "billing_month" shadowed the table column in ON CONFLICT (workspace_id, billing_month).
-- DROP + CREATE so we can rename the return column to result_billing_month (callers using
-- SELECT * get result_billing_month; handle_member_slot_allocation only uses allocated_slots).

DROP FUNCTION IF EXISTS public.get_workspace_slot_info(uuid);
CREATE FUNCTION public.get_workspace_slot_info(p_workspace_id uuid)
RETURNS TABLE(allocated_slots integer, used_slots integer, available_slots integer, result_billing_month date)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  current_month date;
  current_members integer;
  out_allocated integer;
  out_used integer;
  out_available integer;
  out_billing_month date;
BEGIN
  current_month := public.get_current_billing_month();

  SELECT count(*) INTO current_members
  FROM public.workspace_members wm
  WHERE wm.workspace_id = p_workspace_id
    AND wm.status = 'active';

  INSERT INTO public.workspace_billing_slots (workspace_id, billing_month, allocated_slots, used_slots)
  VALUES (p_workspace_id, current_month, greatest(current_members, 1), current_members)
  ON CONFLICT (workspace_id, billing_month)
  DO UPDATE SET
    used_slots = current_members,
    updated_at = now();

  SELECT
    wbs.allocated_slots,
    wbs.used_slots,
    (wbs.allocated_slots - wbs.used_slots),
    wbs.billing_month
  INTO out_allocated, out_used, out_available, out_billing_month
  FROM public.workspace_billing_slots wbs
  WHERE wbs.workspace_id = p_workspace_id
    AND wbs.billing_month = current_month;

  RETURN QUERY SELECT out_allocated, out_used, out_available, out_billing_month;
END;
$function$;
