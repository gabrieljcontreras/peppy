package com.peppy.app.features.onboarding.ui.components

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.peppy.app.ui.theme.CornerRadius
import com.peppy.app.ui.theme.Cream100
import com.peppy.app.ui.theme.Ink100
import com.peppy.app.ui.theme.Ink900

@Composable
fun UnitToggle(
    options: List<String>,
    selectedIndex: Int,
    onSelect: (Int) -> Unit,
    modifier: Modifier = Modifier
) {
    Row(modifier = modifier) {
        options.forEachIndexed { index, label ->
            val isSelected = index == selectedIndex
            val shape = when (index) {
                0 -> RoundedCornerShape(
                    topStart = CornerRadius.pill,
                    bottomStart = CornerRadius.pill,
                    topEnd = 0.dp,
                    bottomEnd = 0.dp
                )
                options.lastIndex -> RoundedCornerShape(
                    topStart = 0.dp,
                    bottomStart = 0.dp,
                    topEnd = CornerRadius.pill,
                    bottomEnd = CornerRadius.pill
                )
                else -> RoundedCornerShape(0.dp)
            }

            if (isSelected) {
                Button(
                    onClick = { onSelect(index) },
                    shape = shape,
                    modifier = Modifier.height(40.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = Ink900,
                        contentColor = Cream100
                    )
                ) {
                    Text(text = label, style = MaterialTheme.typography.labelMedium)
                }
            } else {
                OutlinedButton(
                    onClick = { onSelect(index) },
                    shape = shape,
                    modifier = Modifier.height(40.dp),
                    border = BorderStroke(1.dp, Ink100)
                ) {
                    Text(text = label, style = MaterialTheme.typography.labelMedium)
                }
            }
        }
    }
}
