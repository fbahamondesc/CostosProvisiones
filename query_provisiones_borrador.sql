declare @periodo char(6) = '201801'

SELECT dbo.LOB_Empresa_V.emp_cod
	,dbo.LOB_OBRA_V.obra_cod
	,dbo.LOB_DETALLE_LOB_IC_V.InvtId
	,dbo.LOB_DETALLE_LOB_IC_V.Sub_cod
	,dbo.LOB_DETALLE_LOB_IC_V.monto
	,CONVERT(VARCHAR(4), BxO_DATA.dbo.DOC_APDoc.InvcDate, 102) + CONVERT(VARCHAR(2), BxO_DATA.dbo.DOC_APDoc.InvcDate, 110) periodo_ant
	,BxO_DATA.dbo.BO_Periodos.periodo
INTO #TABLATEMP
FROM dbo.LOB_Empresa_V
INNER JOIN dbo.LOB_DETALLE_LOB_IC_V ON (dbo.LOB_DETALLE_LOB_IC_V.Emp_cod = dbo.LOB_Empresa_V.emp_cod)
INNER JOIN dbo.LOB_OBRA_V ON (
		dbo.LOB_OBRA_V.emp_cod = dbo.LOB_DETALLE_LOB_IC_V.Emp_cod
		AND dbo.LOB_OBRA_V.obra_cod = dbo.LOB_DETALLE_LOB_IC_V.Obra_cod
		)
LEFT OUTER JOIN dbo.LOB_PERIODO_V ON (
		dbo.LOB_DETALLE_LOB_IC_V.Emp_cod = dbo.LOB_PERIODO_V.emp_cod
		AND dbo.LOB_DETALLE_LOB_IC_V.periodo = dbo.LOB_PERIODO_V.periodo
		)
INNER JOIN dbo.BO_Periodos ON (
		dbo.BO_Periodos.periodo = dbo.LOB_PERIODO_V.periodo
		AND dbo.BO_Periodos.CpnyID = dbo.LOB_PERIODO_V.emp_cod
		)
LEFT OUTER JOIN BxO_DATA.dbo.DOC_APDoc ON (BxO_DATA.dbo.DOC_APDoc.apdoc_id = dbo.LOB_DETALLE_LOB_IC_V.Apdoc_ID)
WHERE (
		dbo.LOB_Empresa_V.emp_cod IN (
			'0201'
			,'0202'
			,'0206'
			)
		AND BxO_DATA.dbo.BO_Periodos.periodo >= @periodo
		AND CONVERT(VARCHAR(4), BxO_DATA.dbo.DOC_APDoc.InvcDate, 102) + CONVERT(VARCHAR(2), BxO_DATA.dbo.DOC_APDoc.InvcDate, 110) < dbo.LOB_DETALLE_LOB_IC_V.periodo
		AND dbo.LOB_DETALLE_LOB_IC_V.tipomov <> 'CL-A'
		AND dbo.LOB_DETALLE_LOB_IC_V.Aux_Glosa IN (
			'B.Honorarios'
			,'Fact.Compra'
			,'Fact.Compra Elect.'
			,'Fact.Elect.'
			,'Factura'
			,'Liquidación Factura'
			,'N.Cred.Compra'
			,'N.Cred.Elect.'
			,'N.Deb.Elect.'
			,'Nota Crédito'
			,'Nota Crédito Factura'
			,'Nota de Debito Elect.'
			,'Nota Débito'
			,'Nota Débito OT'
			)
		)

--UPDATE BO_Calculo_Provisiones
--SET costo_provisiones = TT.MONTO
SELECT BCP.*, TT.MONTO
FROM (
	SELECT TT.emp_cod
		,TT.obra_cod
		,TT.InvtId
		,TT.Sub_cod
		,TT.periodo
		,SUM(TT.monto) AS MONTO
	FROM #TABLATEMP TT
	GROUP BY TT.emp_cod
		,TT.obra_cod
		,TT.InvtId
		,TT.Sub_cod
		,TT.periodo
	) TT
JOIN BO_Calculo_Provisiones BCP ON TT.emp_cod = BCP.CpnyID
	AND TT.InvtId = BCP.InsumoLOB
	AND TT.periodo = BCP.PerPost
	AND TT.Sub_cod = BCP.PCO_Subcta
	AND TT.obra_cod = BCP.obra_cod
	AND TT.periodo = BCP.PerPost

DROP TABLE #TABLATEMP

select * from BO_Calculo_Provisiones